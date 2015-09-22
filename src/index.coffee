async = require 'async'
fse = require 'fs-extra'
isFunction = require 'lodash.isfunction'
assign = require 'lodash.assign'
path = require 'path'
pathIsAbsolute = require 'path-is-absolute'
slugify = require 'slugify'

Store = require './store'

class Migrate
  constructor: (@opts={}) ->
    @store = new Store(@opts)
    @opts.path ?= 'migrations'
    @opts.ext ?= 'coffee'
    @opts.template ?= """
      module.exports =
        requiresDowntime: FIXME # true or false

        up: (done) ->
          done()

        down: (done) ->
          throw new Error('irreversible migration')

        test: (done) ->
          done()
    """

  log: (message) ->
    console.log message

  error: (err) ->
    throw err

  get: (pathName) ->
    migrationName = path.basename(pathName, ".#{@opts.ext}")
    pathName = switch
      when pathIsAbsolute(pathName) and fse.existsSync(pathName)
        pathName
      when fse.existsSync(path.join(process.cwd(), pathName))
        path.resolve(process.cwd(), pathName)
      else
        path.resolve(@opts.path, migrationName)

    migration = require pathName
    assign(migration, {name: migrationName})
    assign(migration, @opts.context)

    if @opts.transform?
      migration = @opts.transform migration

    migration

  exists: (name, done) ->
    @store.exists(name, done)

  test: (name, done) ->
    migration = @get(name)
    @log "Testing migration `#{migration.name}`"
    migration.test(done)

  # Run one migration by name
  one: (name, done) ->
    @all [name], done

  # Run all provided migrations or all pending if not provided
  all: (migrations, done) ->
    if isFunction(migrations)
      done = migrations
      migrations = null

    if !migrations?
      return @pending (err, migrations) =>
        return done(err) if err
        @all(migrations, done)

    runIndividualMigration = (name, doneWithIndividualMigration) =>
      @exists name, (err, exists) =>
        return doneWithIndividualMigration(err) if err
        return doneWithIndividualMigration(@error new Error "Migration `#{name}` has already been run") if exists
        migration = @get name
        @log "Running migration `#{migration.name}`"
        migration.up (err) =>
          return doneWithIndividualMigration(err) if err
          @store.save(migration.name, doneWithIndividualMigration)

    async.eachSeries migrations, runIndividualMigration, done

  down: (done) ->
    @store.getMostRecent (err, name) =>
      return done(err) if err
      return done(@error new Error("No migrations found!")) if not name?
      migration = @get(name)
      @log "Reversing migration `#{migration.name}`"
      migration.down (err) =>
        return done(err) if err
        @store.remove(name, done)

  # Return a list of pending migrations
  pending: (done) ->
    async.parallel [
      ((innerDone) => fse.readdir @opts.path, innerDone)
      ((innerDone) => @store.getAll(innerDone))
    ], (err, results) =>
      return done(err) if err
      filenames = results[0].sort()
      migrationsAlreadyRun = results[1]
      names = filenames.map (filename) =>
        return unless (match = filename.match new RegExp "^([^_].+)\.#{@opts.ext}$")
        match[1]
      .filter (name) ->
        !!name
      .filter (name) ->
        name not in migrationsAlreadyRun
      done(null, names)

  # Generate a stub migration file
  generate: (name, done) ->
    name = "#{slugify name, '_'}"
    timestamp = (new Date()).toISOString().replace /\D/g, ''
    filename = "#{@opts.path}/#{timestamp}_#{name}.#{@opts.ext}"
    async.series [
      ((innerDone) => fse.mkdirp @opts.path, innerDone)
      ((innerDone) => fse.writeFile filename, @opts.template, innerDone)
    ], (err) ->
      return done(err) if err
      done(null, filename)

module.exports = Migrate

