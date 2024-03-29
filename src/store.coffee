mongoose = require 'mongoose'

module.exports = class MongoStore
  constructor: (@opts={}) ->
    @_model = @opts.model
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

  model: ->
    @_model ?= do =>
      if typeof @opts.mongo isnt 'object'
        throw new Error('`mongo` Migratefile option must now be an object {url, options}')
      {url, options} = @opts.mongo
      if not url?
        throw new Error('`mongo.url` Migratefile option is required')
      connection = mongoose.createConnection(url, options)

      schema = new mongoose.Schema
        name:  type: String, index: true, unique: true, required: true
        createdAt:  type: Date, default: Date.now

      connection.model 'MigrationVersion', schema, 'migration_versions'

  exists: (name, done) ->
    @model().countDocuments({name}, (err, count) ->
      return done(err) if err
      done(null, count > 0)
    )

  save: (name, done) ->
    @model().create({name}, done)

  remove: (name, done) ->
    @model().deleteOne({name}, done)

  getMostRecent: (done) ->
    @model().findOne {}, {name: 1}, {sort: 'name': -1}, (err, version) =>
      return done(err) if err
      return done(null, version?.name ? null)

  getAll: (done) ->
    @model().distinct('name', done)
