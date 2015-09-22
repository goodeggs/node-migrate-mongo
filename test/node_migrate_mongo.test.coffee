{expect} = chai = require 'chai'
fibrous = require 'fibrous'
fse = require 'fs-extra'
sinon = require 'sinon'
path = require 'path'
chai.use require 'sinon-chai'
Migrate = require '../'

class StubMigrationVersion
  @find: ->
  @findOne: ->
  @create: ->
  @distinct: ->
  @count: ->
  @remove: ->

describe 'node-migrate-mongo', ->
  migrate = null

  before ->
    opts =
      path: path.join(__dirname, 'test-migrations')
      model: StubMigrationVersion
      context:
        foo: 'bar'
    migrate = new Migrate opts
    sinon.stub(migrate, 'log')

    # changing directory so we can be sure what process.cwd() will point to
    process.chdir path.join(__dirname)

  after ->
    migrate.log.restore()

  describe '.get', ->
    migration = null

    describe 'given a file in the opts.path path', ->
      before ->
        migration = migrate.get 'migration'

      it 'loads ok', ->
        expect(migration).to.be.ok

      it 'has name', ->
        expect(migration.name).to.equal 'migration'

      it 'has context', ->
        expect(migration.foo).to.equal 'bar'

    describe 'given a full path to a file', ->
      before ->
        migration = migrate.get path.join(__dirname, 'migration.coffee')

      it 'loads ok', ->
        expect(migration).to.be.ok

      it 'has name', ->
        expect(migration.name).to.equal 'migration'

      it 'has context', ->
        expect(migration.foo).to.equal 'bar'

    describe 'given a partial path to a file', ->
      before ->
        migration = migrate.get path.join(__dirname, 'migration')

      it 'loads ok', ->
        expect(migration).to.be.ok

      it 'has name', ->
        expect(migration.name).to.equal 'migration'

      it 'has context', ->
        expect(migration.foo).to.equal 'bar'

    describe 'given a relative path to a file', ->
      before ->
        migration = migrate.get path.join('test-migrations', 'migration.coffee')

      it 'loads ok', ->
        expect(migration).to.be.ok

      it 'has name', ->
        expect(migration.name).to.equal 'migration'

      it 'has context', ->
        expect(migration.foo).to.equal 'bar'

    describe 'given config including a transform', ->
      beforeEach 'set up Migrate with a transform', ->
        @migrate2 = new Migrate
          path: path.join(__dirname, 'test-migrations')
          model: StubMigrationVersion
          transform: (migration) ->
            migration.herp = 'derp'
            migration
        sinon.stub @migrate2, 'log'

      afterEach ->
        @migrate2.log.restore()

      it 'calls the transform', ->
        migration = @migrate2.get 'migration'
        expect(migration.herp).to.equal 'derp'

  describe '.exists', ->
    before fibrous ->
      sinon.stub StubMigrationVersion, 'count', ({name}, cb) ->
        cb null, if name is 'existing' then 1 else 0

    after ->
      StubMigrationVersion.count.restore()

    it 'returns true for existing migration', fibrous ->
      expect(migrate.sync.exists 'existing').to.eql true

    it 'returns false for existing migration', fibrous ->
      expect(migrate.sync.exists 'non_existing').to.eql false

  describe '.test', ->
    migration = null

    before fibrous ->
      migration =
        name: 'migration'
        test: sinon.stub().yields()
        foo: 'bar'
      sinon.stub(migrate, 'get').returns migration
      migrate.sync.test('migration')

    after ->
      migrate.get.restore()

    it 'executes migration test', fibrous ->
      expect(migration.test).to.have.been.calledOnce

    it 'provides text with context', fibrous ->
      expect(migration.test).to.have.been.calledOn sinon.match foo: 'bar'

  describe '.one', ->
    migration = null

    before fibrous ->
      migration =
        name: 'pending_migration'
        up: sinon.stub().yields()
        foo: 'bar'
      sinon.stub(migrate, 'exists').yields null, false
      sinon.stub(migrate, 'get').returns migration
      sinon.stub(StubMigrationVersion, 'create').yields()
      migrate.sync.one 'pending_migration'

    after ->
      StubMigrationVersion.create.restore()
      migrate.get.restore()
      migrate.exists.restore()

    it 'calls up on migration', fibrous ->
      expect(migration.up).to.have.been.calledOnce

    it 'provides up with context', fibrous ->
      expect(migration.up).to.have.been.calledOn sinon.match foo: 'bar'

    it 'saves new migration', fibrous ->
      expect(StubMigrationVersion.create).to.have.been.calledWithMatch name: 'pending_migration'

  describe '.all', ->
    migration = null

    describe 'migrating all pending', ->
      before fibrous ->
        migration =
          name: 'pending_migration'
          up: sinon.stub().yields()
          foo: 'bar'
        sinon.stub(migrate, 'pending').yields null, ['pending_migration']
        sinon.stub(migrate, 'exists').yields null, false
        sinon.stub(migrate, 'get').returns migration
        sinon.stub(StubMigrationVersion, 'create').yields()
        migrate.sync.all()

      after ->
        StubMigrationVersion.create.restore()
        migrate.pending.restore()
        migrate.get.restore()
        migrate.exists.restore()

      it 'calls up on migration', fibrous ->
        expect(migration.up).to.have.been.calledOnce

      it 'provides up with context', fibrous ->
        expect(migration.up).to.have.been.calledOn sinon.match foo: 'bar'

      it 'saves new migration', fibrous ->
        expect(StubMigrationVersion.create).to.have.been.calledWithMatch name: 'pending_migration'

    describe 'migrating existing migration', ->
      before fibrous ->
        migration =
          name: 'existing_migration'
          up: sinon.stub().yields()
          foo: 'bar'
        sinon.stub(migrate, 'pending').yields null, ['existing_migration']
        sinon.stub(migrate, 'exists').yields null, true
        sinon.stub(migrate, 'get').returns migration
        sinon.stub migrate, 'error'
        sinon.stub(StubMigrationVersion, 'create').yields()
        migrate.sync.all()

      after ->
        StubMigrationVersion.create.restore()
        migrate.error.restore()
        migrate.pending.restore()
        migrate.get.restore()
        migrate.exists.restore()

      it 'does not call up on migration', fibrous ->
        expect(migration.up).to.not.have.been.calledOnce

      it 'does not save new migration', fibrous ->
        expect(StubMigrationVersion.create).to.not.have.been.called

      it 'calls error', fibrous ->
        expect(migrate.error).to.have.been.calledOnce

  describe '.down', ->
    {migration, version} = {}

    before fibrous ->
      migration =
        name: 'migration'
        down: sinon.stub().yields()
        foo: 'bar'
      sinon.stub(migrate, 'get').returns migration

      version =
        name: 'migration'
        remove: sinon.stub().yields()
      sinon.stub(StubMigrationVersion, 'findOne').yields null, version
      sinon.stub(StubMigrationVersion, 'remove').yields null, 1

      migrate.sync.down()

    after ->
      StubMigrationVersion.findOne.restore()
      StubMigrationVersion.remove.restore()
      migrate.get.restore()

    it 'calls down on the migration', fibrous ->
      expect(migration.down).to.have.been.calledOnce

    it 'provides down with context', fibrous ->
      expect(migration.down).to.have.been.calledOn sinon.match foo: 'bar'

    it 'removes version', fibrous ->
      expect(StubMigrationVersion.remove).to.have.been.calledWith sinon.match name: 'migration'

  describe '.pending', ->
    {pending} = {}

    scenarioForFileExtension = (ext) ->
      before fibrous ->
        migrate2 = new Migrate {path: __dirname, ext: ext, model: StubMigrationVersion}
        sinon.stub(fse, 'readdir').yieldsAsync null, ["migration3.#{ext}", "migration2.#{ext}", "migration1.#{ext}"]
        sinon.stub(StubMigrationVersion, 'distinct').yieldsAsync null, ['migration1']
        pending = migrate2.sync.pending()

      after ->
        fse.readdir.restore()
        StubMigrationVersion.distinct.restore()

      it 'returns pending migrations', fibrous ->
        expect(pending).to.eql ['migration2', 'migration3']

    describe 'coffee-script', ->
      scenarioForFileExtension 'coffee'

    describe 'javascript', ->
      scenarioForFileExtension 'js'

  describe '.generate', ->
    before fibrous ->
      sinon.stub(fse, 'mkdirp').yields()
      sinon.stub(fse, 'writeFile').yields()
      migrate.sync.generate 'filename'

    after ->
      fse.mkdirp.restore()
      fse.writeFile.restore()

    it 'generates migration file', fibrous ->
      expect(fse.writeFile).to.have.been.calledWithMatch /^.*_filename/, /.+/
