# CHANGELOG

## v3.0.0

### Breaking changes

Previously, the Migratefile `mongo` option supported either a MongoDB connection URL string,
or a function that returned such a string.
```js
// NO LONGER SUPPORTED
{
  mongo: 'mongodb://localhost:27017/foo',
}
```

```js
// NO LONGER SUPPORTED
{
  mongo: () => 'mongodb://localhost:27017/foo',
}
```

Now, this option only supports an object with a required `url` string and an optional `options`
object:
```js
// NEW SIGNATURE
{
  mongo: {
    url: 'mongodb://localhost:27017/foo',
  },
}
```

```js
// NEW SIGNATURE, with options
{
  mongo: {
    url: 'mongodb://localhost:27017/foo',
    options: {
      // any MongoDB client driver connection options, e.g.:
      connectTimeoutMS: 30000,
    },
  },
}
```
