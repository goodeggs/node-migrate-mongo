#!/usr/bin/env node
var Liftoff = require('liftoff');
var argv = require('minimist')(process.argv.slice(2));

var MigrateCli = new Liftoff({
  name: 'migrate',
  extensions: require('interpret').jsVariants
});

MigrateCli.launch({
  cwd: argv.cwd,
  configPath: argv.migratefile,
  require: argv.require,
  completion: argv.completion,
  verbose: argv.verbose
}, function(env) {

  if (!env.configPath) {
    console.error('No Migratefile found.');
    process.exit(1);
  }

  process.chdir(env.configBase);
  var config = require(env.configPath);
  require('../lib/cli.js')(config, argv);
});
