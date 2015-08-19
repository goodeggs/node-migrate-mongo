async = require 'async'

module.exports = (config, argv) ->

  config.beforeTest ?= (cb) ->
    process.env.NODE_ENV ?= 'test'
    process.nextTick(cb)

  Migrate = require '../'
  class CustomMigrate extends Migrate
    log: config.log or (message) ->
      console.log message
    error: config.error or (err) ->
      console.error err.printStack is false and err.message or err.stack
      process.exit 1

  # opts: ext, path, template, mongo
  trimmedConfig = {}
  trimmedConfig[k] = v for k, v of config when k in ['ext', 'path', 'template', 'mongo', 'context']
  migrate = new CustomMigrate trimmedConfig

  die = (message) ->
    err = new Error message
    err.printStack = false
    migrate.error(err)

  usage = ->
    console.error 'Usage: migrate <generate|one|down|pending|all|test [--name <migration_name>]>'
    process.exit 0

  usage() if argv.help

  command = argv._[0]

  steps = []

  steps.push config.beforeTest.bind(config) if command is 'test' and config.beforeTest?
  steps.push config.before.bind(config) if config.before?

  switch command
    when 'generate'
      die('must provide migration name with --name') unless argv.name
      steps.push (cb) -> migrate.generate argv.name, (err, filename) ->
        return cb(err) if err?
        migrate.log "Created `#{filename}`"
        cb()

    when 'one'
      die('must provide migration name with --name') unless argv.name
      steps.push migrate.one.bind(migrate, argv.name)

    when 'down'
      steps.push migrate.down.bind(migrate)

    when 'pending'
      steps.push (cb) ->
        migrate.pending (err, pendingNames) ->
          return cb(err) if err?
          if pendingNames.length
            for name in pendingNames
              {requiresDowntime} = migrate.get name
              migrate.log "Migration `#{name}` is pending #{requiresDowntime and "(requires downtime)" or ''}"
          else
            migrate.log 'No pending migrations'
          cb()

    when 'all'
      steps.push migrate.all.bind(migrate)

    when 'test'
      die('must provide migration name with --name') unless argv.name
      steps.push migrate.test.bind(migrate, argv.name)

    else
      usage()

  steps.push config.after.bind(config) if config.after?
  steps.push config.afterTest.bind(config) if command is 'test' and config.afterTest?

  async.series steps, (err) ->
    return migrate.error err if err?
    process.exit 0

