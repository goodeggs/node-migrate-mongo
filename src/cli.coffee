module.exports = (config, argv) ->

  Migrate = require '../'
  class CustomMigrate extends Migrate
    log: config.log or (message) ->
      console.log message
    error: config.error or (err) ->
      console.error err.printStack and err or err.message
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

      #when 'one'
      #when 'test'
      #when 'down'
      #when 'pending'
      #when 'all'
      
  catch err
    migrate.error err

