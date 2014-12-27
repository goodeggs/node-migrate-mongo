module.exports = (config, argv) ->

  Migrate = require '../'
  class CustomMigrate extends Migrate
    log: config.log or (message) ->
      console.log message
    error: config.error or (err) ->
      console.error err.printStack is false and err.message or err.stack
      process.exit 1

  # opts: ext, path, template, mongo
  trimmedConfig = {}
  trimmedConfig[k] = v for k, v of config when k in ['ext', 'path', 'template', 'mongo']
  migrate = new CustomMigrate trimmedConfig

  die = (message) ->
    err = new Error message
    err.printStack = false
    migrate.error(err)

  try
    command = argv._[0]

    switch command
      when 'generate'
        die('must provide migration name with --name') unless argv.name
        migrate.generate argv.name, (err, filename) ->
          return migrate.error(err) if err?
          migrate.log "Created `#{filename}`"
          process.exit 0

      when 'one'
        die('must provide migration name with --name') unless argv.name
        migrate.one argv.name, (err, success) ->
          return migrate.error(err) if err?
          process.exit(if success then 0 else 1)

      when 'down'
        migrate.down (err) ->
          return migrate.error(err) if err?
          process.exit 0

      when 'pending'
        migrate.pending (err, pendingNames) ->
          return migrate.error(err) if err?
          if pendingNames.length
            for name in pendingNames
              {requiresDowntime} = migrate.get name
              migrate.log "Migration `#{name}` is pending #{requiresDowntime and "(requires downtime)" or ''}"
          else
            migrate.log 'No pending migrations'
          process.exit 0
          
      when 'all'
        migrate.all (err) ->
          return migrate.error(err) if err?
          process.exit 0

      when 'test'
        die('must provide migration name with --name') unless argv.name
        migrate.test argv.name, (err) ->
          return migrate.error(err) if err?
          process.exit 0
      
  catch err
    migrate.error err

