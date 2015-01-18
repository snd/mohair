_ = require 'lodash'
criterion = require 'criterion'

# pull in some helpers from criterion

# TODO put this directly on criterion
{
  implementsSqlFragmentInterface
} = criterion.helper
################################################################################
# PROTOTYPES & FACTORIES

# prototype objects for the action-objects that represent sql actions.
# sql actions are: select, insert, update and delete.
# action-objects store just the state specific to that action.
# the rest is stored in mohair itself.

prototypes = {}

# factory functions that make action-objects by prototypically
# inheriting from the prototypes.
# try to catch errors in the factory functions.

factories = {}

################################################################################
# PARTIALS

################################################################################
# items joined by a separator character

prototypes.joinedItems =
  sql: (escape) ->
    parts = []
    @_items.forEach (item) ->
      if implementsSqlFragmentInterface item
        # sql fragment
        itemSql = item.sql(escape)
        unless item.dontWrap
          itemSql = '(' + itemSql + ')'
        parts.push itemSql
      else
        # simple string
        parts.push item
    return parts.join @_join
  params: ->
    params = []
    @_items.forEach (item) ->
      if implementsSqlFragmentInterface item
        # sql fragment
        params = params.concat item.params()
    return params
  dontWrap: true

factories.joinedItems = (join, items...) ->
  _.create prototypes.joinedItems,
    _join: join
    _items: _.flatten items

################################################################################
# aliases: `table AS alias`

prototypes.aliases =
  sql: (escape) ->
    object = @_object
    escapeStringValues = @_escapeStringValues
    parts = []
    Object.keys(object).forEach (key) ->
      value = object[key]
      if implementsSqlFragmentInterface value
        valueSql = value.sql(escape)
        unless value.dontWrap
          valueSql = '(' + valueSql + ')'
        parts.push valueSql + ' AS ' + escape(key)
      else
        parts.push (if escapeStringValues then escape(value) else value) + ' AS ' + escape(key)
    parts.join(', ')
  params: ->
    object = @_object
    params = []
    # aliased
    Object.keys(object).forEach (key) ->
      value = object[key]
      if implementsSqlFragmentInterface value
        params = params.concat value.params()
    params
  dontWrap: true

factories.aliases = (object, escapeStringValues = false) ->
  if Object.keys(object).length is 0
    throw new Error 'alias object must have at least one property'
  _.create prototypes.aliases,
    _object: object
    _escapeStringValues: escapeStringValues

################################################################################
# select outputs

# plain strings are treated raw and not escaped
# objects are used for aliases

factories.selectOutputs = (outputs...) ->
  if outputs.length is 0
    return criterion('*')

  factories.joinedItems ', ', _.flatten(outputs).map (output) ->
    if implementsSqlFragmentInterface output
      output
    else if 'object' is typeof output
      # alias object
      factories.aliases output
    else
      # raw strings are not escaped
      criterion output

################################################################################
# from items

factories.fromItems = (items...) ->
  factories.joinedItems ', ', _.flatten(items).map (item) ->
    if implementsSqlFragmentInterface item
      item
    else if 'object' is typeof item
      # alias object
      escapeStringValues = true
      factories.aliases item, escapeStringValues
    else
      # strings are interpreted as table names and escaped
      criterion.escape item

################################################################################
# ACTIONS: select, insert, update, delete

################################################################################
# select

prototypes.select =
  sql: (mohair, escape) ->
    sql = ''

    # common table expression ?
    if mohair._with?
      sql += 'WITH '
      parts = []
      parts = Object.keys(mohair._with).map (key) ->
        escape(key) + ' AS (' + criterion(mohair._with[key]).sql(escape) + ')'
      sql += parts.join(', ')
      sql += ' '

    sql += "SELECT"

    if mohair._distinct?
      sql += " DISTINCT #{mohair._distinct}"

    sql += " "

    # what to select
    sql += @_outputs.sql(escape)

    # where to select from:

    # from takes precedence over table
    if mohair._from?
      sql += " FROM #{mohair._from.sql(escape)}"
    else if mohair._table?
      sql += " FROM #{escape mohair._table}"

    mohair._joins.forEach (join) ->
      sql += " #{join.sql}"
      if join.criterion?
        sql += " AND (#{join.criterion.sql(escape)})"

    # how to modify the select

    if mohair._where?
      sql += " WHERE #{mohair._where.sql(escape)}"
    if mohair._group?
      sql += " GROUP BY #{mohair._group.join(', ')}"
    if mohair._having?
      sql += " HAVING #{mohair._having.sql(escape)}"
    if mohair._window?
      sql += " WINDOW #{mohair._window}"
    if mohair._order?
      sql += " ORDER BY #{mohair._order.join(', ')}"
    if mohair._limit?
      sql += ' LIMIT '
      if implementsSqlFragmentInterface mohair._limit
        sql += mohair._limit.sql(escape)
      else
        sql += '?'
    if mohair._offset?
      sql += ' OFFSET '
      if implementsSqlFragmentInterface mohair._offset
        sql += mohair._offset.sql(escape)
      else
        sql += '?'
    if mohair._for?
      sql += " FOR #{mohair._for}"

    # combination with other queries ?

    if mohair._combinations?
      mohair._combinations.forEach (combination) ->
        sql += " #{combination.operator} #{combination.query.sql(escape)}"

    return sql

  params: (mohair) ->
    params = []

    if mohair._with?
      Object.keys(mohair._with).forEach (key) ->
        params = params.concat criterion(mohair._with[key]).params()

    params = params.concat @_outputs.params()

    if mohair._from?
      params = params.concat mohair._from.params()

    mohair._joins.forEach (join) ->
      if join.criterion?
        params = params.concat join.criterion.params()

    if mohair._where?
      params = params.concat mohair._where.params()
    if mohair._having?
      params = params.concat mohair._having.params()
    if mohair._limit?
      if implementsSqlFragmentInterface mohair._limit
        params = params.concat mohair._limit.params()
      else
        params.push mohair._limit
    if mohair._offset?
      if implementsSqlFragmentInterface mohair._offset
        params = params.concat mohair._offset.params()
      else
        params.push mohair._offset

    if mohair._combinations?
      mohair._combinations.forEach (combination) ->
        params = params.concat combination.query.params()

    return params

factories.select = (outputs...) ->
  _.create prototypes.select,
    _outputs: factories.selectOutputs outputs...

################################################################################
# insert

prototypes.insert =
  sql: (mohair, escape) ->
    unless mohair._table?
      throw new Error '.sql() of insert action requires call to .table() before it'

    if mohair._from?
      throw new Error '.sql() of insert action ignores and does not allow call to .from() before it'

    table = escape mohair._table

    records = @_records

    keys = Object.keys(records[0])

    escapedKeys = keys.map escape

    rows = records.map (record) ->
      row = keys.map (key) ->
        if implementsSqlFragmentInterface record[key]
          record[key].sql(escape)
        else
          '?'
      return "(#{row.join ', '})"

    sql = "INSERT INTO #{table}(#{escapedKeys.join ', '}) VALUES #{rows.join ', '}"

    if mohair._returning?
      sql += " RETURNING #{mohair._returning.sql(escape)}"

    return sql

  params: (mohair) ->
    records = @_records

    keys = Object.keys(records[0])

    params = []

    records.forEach (record) ->
      keys.forEach (key) ->
        if implementsSqlFragmentInterface record[key]
          params = params.concat record[key].params()
        else
          params.push record[key]

    if mohair._returning?
      params = params.concat mohair._returning.params()

    return params

factories.insert = (recordOrRecords) ->
  if Array.isArray recordOrRecords
    if recordOrRecords.length is 0
      throw new Error 'array argument is empty - no records to insert'

    msg = 'all records in the array argument must have the same keys.'
    keysOfFirstRecord = Object.keys recordOrRecords[0]
    if keysOfFirstRecord.length is 0
      throw new Error "can't insert empty object"
    recordOrRecords.forEach (record) ->
      keys = Object.keys record
      if keys.length isnt keysOfFirstRecord.length
        throw new Error msg

      keysOfFirstRecord.forEach (key) ->
        value = record[key]
        # null values are allowed !
        if not value? and record[key] isnt null
          throw new Error msg

    return _.create prototypes.insert, {_records: recordOrRecords}

  if 'object' is typeof recordOrRecords
    if Object.keys(recordOrRecords).length is 0
      throw new Error "can't insert empty object"
    return _.create prototypes.insert, {_records: [recordOrRecords]}

  throw new TypeError 'argument must be an object or an array'

################################################################################
# update

prototypes.update =
  sql: (mohair, escape) ->
    updates = @_updates

    unless mohair._table?
      throw new Error '.sql() of update action requires call to .table() before it'

    table = escape mohair._table
    keys = Object.keys updates

    updatesSql = keys.map (key) ->
      escapedKey = escape key
      if implementsSqlFragmentInterface updates[key]
        "#{escapedKey} = #{updates[key].sql(escape)}"
      else
        "#{escapedKey} = ?"

    sql = "UPDATE #{table} SET #{updatesSql.join ', '}"
    if mohair._from?
      sql += " FROM #{mohair._from.sql(escape)}"
    if mohair._where?
      sql += " WHERE #{mohair._where.sql(escape)}"
    if mohair._returning?
      sql += " RETURNING #{mohair._returning.sql(escape)}"
    return sql

  params: (mohair) ->
    updates = @_updates

    params = []

    Object.keys(updates).forEach (key) ->
      value = updates[key]
      if implementsSqlFragmentInterface value
        params = params.concat value.params()
      else
        params.push value

    if mohair._from?
      params = params.concat mohair._from.params()

    if mohair._where?
      params = params.concat mohair._where.params()
    if mohair._returning?
      params = params.concat mohair._returning.params()

    return params

factories.update = (updates) ->
  if Object.keys(updates).length is 0
    throw new Error 'nothing to update'
  _.create prototypes.update,
    _updates: updates

################################################################################
# delete

prototypes.delete =
  sql: (mohair, escape) ->
    unless mohair._table?
      throw new Error '.sql() of delete action requires call to .table() before it'

    table = escape mohair._table
    sql = "DELETE FROM #{table}"
    # from for delete acts as using
    if mohair._from?
      sql += " USING #{mohair._from.sql(escape)}"
    if mohair._where?
      sql += " WHERE #{mohair._where.sql(escape)}"
    if mohair._returning?
      sql += " RETURNING #{mohair._returning.sql(escape)}"
    return sql

  params: (mohair) ->
    params = []
    if mohair._from?
      params = params.concat mohair._from.params()
    if mohair._where?
      params = params.concat mohair._where.params()
    if mohair._returning?
      params = params.concat mohair._returning.params()
    return params

factories.delete = ->
  _.create prototypes.delete

################################################################################
# MOHAIR FLUENT API

Mohair = (source) ->
  if source
    # only copy OWN properties.
    # don't copy properties on the prototype.
    # OWN properties are just non-default values and user defined methods.
    # OWN properties tend to be very few for most queries.
    for own k, v of source
      this[k] = v
  return this

Mohair.prototype =

################################################################################
# core

  fluent: (key, value) ->
    next = new Mohair @
    next[key] = value
    return next

  _escape: _.identity
  escape: (arg) -> @fluent '_escape', arg

  # the default action is select *
  _action: factories.select '*'

################################################################################
# actions

  insert: (args...) -> @fluent '_action', factories.insert args...
  select: (args...) -> @fluent '_action', factories.select args...
  delete: -> @fluent '_action', factories.delete()
  update: (data) -> @fluent '_action', factories.update data

################################################################################
# for select action only

  with: (arg) ->
    unless ('object' is typeof arg) and Object.keys(arg).length isnt 0
      throw new Error 'with must be called with an object that has at least one property'
    @fluent '_with', arg
  distinct: (arg = '') ->
    @fluent '_distinct', arg
  group: (args...) ->
    @fluent '_group', args
  window: (arg) ->
    @fluent '_window', arg
  order: (args...) ->
    @fluent '_order', args
  limit: (arg) ->
    @fluent '_limit',
      if implementsSqlFragmentInterface arg
        arg
      else
        parseInt(arg, 10)
  offset: (arg) ->
    @fluent '_offset',
      if implementsSqlFragmentInterface arg
        arg
      else
        parseInt(arg, 10)
  for: (arg) ->
    @fluent '_for', arg

################################################################################
# from

  # supports multiple tables, subqueries and aliases
  # from: (from...) ->
  #   @fluent '_from', from...

  getTable: ->
    @_table

  # table must be a simple string
  table: (table) ->
    if 'string' isnt typeof table
      throw new Error 'table must be a string. use .from() to call with multiple tables or subqueries.'
    @fluent '_table', table

  from: (args...) ->
    @fluent '_from', factories.fromItems args...

  _joins: []
  join: (sql, criterionArgs...) ->
    join = {sql: sql}
    join.criterion = criterion criterionArgs... if criterionArgs.length isnt 0

    next = new Mohair @
    # slice without arguments clones an array
    next._joins = @_joins.slice()
    next._joins.push join

    return next

################################################################################
# where conditions

  where: (args...) ->
    where = criterion args...
    @fluent '_where', if @_where? then @_where.and(where) else where

  having: (args...) ->
    having = criterion args...
    @fluent '_having', if @_having? then @_having.and(having) else having

################################################################################
# returning (ignored for select)

  returning: (args...) ->
    # returning can be disabled by calling without arguments
    if args.length is 0
      @fluent '_returning', null
    else
      @fluent '_returning', factories.selectOutputs args...

################################################################################
# combining queries (select only)

  _combinations: []
  combine: (query, operator) ->
    # slice without arguments clones an array
    combinations = @_combinations.slice()
    combinations.push
      query: query
      operator: operator
    @fluent '_combinations', combinations

  union: (query) ->
    @combine query, 'UNION'
  unionAll: (query) ->
    @combine query, 'UNION ALL'
  intersect: (query) ->
    @combine query, 'INTERSECT'
  intersectAll: (query) ->
    @combine query, 'INTERSECT ALL'
  except: (query) ->
    @combine query, 'EXCEPT'
  exceptAll: (query) ->
    @combine query, 'EXCEPT ALL'

################################################################################
# helpers

  # call a one-off function as if it were part of mohair
  call: (fn, args...) ->
    fn.apply @, args

  raw: (sql, params...) ->
    criterion sql, params...

################################################################################
# implementation of sql-fragment interface

  sql: (escape) ->
    # escape can be passed in to override the escape set on this mohair
    @_action.sql @, (escape or @_escape)

  params: ->
    @_action.params @

  implementsSqlFragmentInterface: implementsSqlFragmentInterface

################################################################################
# exports

module.exports = new Mohair
