path = require 'path'
fse = require 'fs-extra'
mongoose = require 'mongoose'
fibrous = require 'fibrous'
slugify = require 'slugify'

class Migrate
  constructor: (@opts, @model) ->
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
          console.log 'copying development to test'
          require('child_process').exec "mongo test --eval \\"db.dropDatabase(); db.copyDatabase('development', 'test'); print('copied')\\"", ->
            done()
    """
    @getModel()

  getModel: ->
    @model ?= do =>
      @opts.mongo = @opts.mongo() if typeof @opts.mongo is 'function'
      connection = mongoose.createConnection @opts.mongo

      schema = new mongoose.Schema
        name:  type: String, index: true, unique: true, required: true
        createdAt:  type: Date, default: Date.now

      connection.model 'MigrationVersion', schema, 'migration_versions'

  getTemplate: (name) -> @opts.template

  log: (message) ->
    console.log message

  error: (err) ->
    throw err

  get: (name) ->
    name = name.replace new RegExp("\.#{@opts.ext}$"), ''
    migration = require path.resolve("#{@opts.path}/#{name}")
    migration.name = name
    migration

  # Check a migration has been run
  exists: fibrous (name) ->
    @getModel().sync.findOne({name})?

  test: fibrous (name) ->
    @log "Testing migration `#{name}`"
    @get(name).sync.test()

  # Run one migration by name
  one: fibrous (name) ->
    @sync.all([name])

  # Run all provided migrations or all pending if not provided
  all: fibrous (migrations) ->
    migrations = @sync.pending() if !migrations?
    for name in migrations
      if @sync.exists(name)
        return @error new Error "Migration `#{name}` has already been run"
      migration = @get(name)
      @log "Running migration `#{migration.name}`"
      migration.sync.up()
      @getModel().sync.create name: migration.name

  down: fibrous ->
    version = @getModel().sync.findOne {}, {name: 1}, {sort: 'name': -1}
    return @error new Error("No migrations found!") if not version?
    migration = @get(version.name)
    @log "Reversing migration `#{migration.name}`"
    migration.sync.down()
    version.sync.remove()

  # Return a list of pending migrations
  pending: fibrous ->
    filenames = fse.sync.readdir(@opts.path).sort()
    migrationsAlreadyRun = @getModel().sync.distinct('name')
    names = filenames.map (filename) =>
      return unless (match = filename.match new RegExp "^([^_].+)\.#{@opts.ext}$")
      match[1]
    .filter (name) ->
      !!name
    .filter (name) ->
      name not in migrationsAlreadyRun
    names

  # Generate a stub migration file
  generate: fibrous (name) ->
    name = "#{slugify name, '_'}"
    timestamp = (new Date()).toISOString().replace /\D/g, ''
    filename = "#{@opts.path}/#{timestamp}_#{name}.#{@opts.ext}"
    fse.sync.mkdirp @opts.path
    fse.sync.writeFile filename, @getTemplate name
    filename

module.exports = Migrate

