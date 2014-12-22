criterion = require 'criterion'

# pull in some helpers from criterion

{
  identity
  beget
  implementsSqlFragmentInterface
  flatten
} = criterion.helper

###################################################################################
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

###################################################################################
# PARTIALS

###################################################################################
# comma separated

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
  beget prototypes.joinedItems,
    _join: join
    _items: flatten items

###################################################################################
# alias

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
  beget prototypes.aliases,
    _object: object
    _escapeStringValues: escapeStringValues

###################################################################################
# select output

# plain strings are treated raw and not escaped
# objects are used for aliases

factories.selectOutputs = (outputs...) ->
  if outputs.length is 0
    return criterion('*')

  factories.joinedItems ', ', outputs.map (output) ->
    if implementsSqlFragmentInterface output
      output
    else if 'object' is typeof output
      # alias object
      factories.aliases output
    else
      # raw strings are not escaped
      criterion output

###################################################################################
# from items

factories.fromItems = (items...) ->
  factories.joinedItems ', ', items.map (item) ->
    if implementsSqlFragmentInterface item
      item
    else if 'object' is typeof item
      # alias object
      escapeStringValues = true
      factories.aliases item, escapeStringValues
    else
      # strings are interpreted as table names and escaped
      criterion.escape item

###################################################################################
# ACTIONS: select, insert, update, delete

###################################################################################
# select

prototypes.select =
  sql: (mohair, escape) ->
    outputs = @_outputs

    table = escape mohair._table

    sql = ''

    # common table expression ?
    if mohair._with?
      sql += 'WITH '
      parts = []
      parts = Object.keys(mohair._with).map (key) ->
          escape(key) + ' AS (' + criterion(mohair._with[key]).sql(escape) + ')'
      sql += parts.join(', ')
      sql += ' '

    sql += "SELECT "

    # what to select
    sql += outputs.sql(escape)

    # where to select from:

    if mohair._from?
      sql += " FROM #{mohair._from.sql(escape)}"
    mohair._joins.forEach (join) ->
      sql += " #{join.sql}"
      sql += " AND (#{join.criterion.sql(escape)})" if join.criterion?

    # who to modify the select

    sql += " WHERE #{mohair._where.sql(escape)}" if mohair._where?
    sql += " GROUP BY #{mohair._group}" if mohair._group?
    sql += " HAVING #{mohair._having.sql(escape)}" if mohair._having?
    sql += " ORDER BY #{mohair._order}" if mohair._order?
    sql += " LIMIT ?" if mohair._limit?
    sql += " OFFSET ?" if mohair._offset?

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
      params.push mohair._limit
    if mohair._offset?
      params.push mohair._offset

    if mohair._combinations?
      mohair._combinations.forEach (combination) ->
        params = params.concat combination.query.params()

    return params

factories.select = (outputs...) ->
  beget prototypes.select,
    _outputs: factories.selectOutputs outputs...

###################################################################################
# insert

prototypes.insert =
  sql: (mohair, escape) ->
    unless mohair._from?
      throw new Error '.sql() of insert action requires call to .table() before it'

    table = mohair._from.sql(escape)

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

    params = params.concat mohair._from.params()

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

    return beget prototypes.insert, {_records: recordOrRecords}

  if 'object' is typeof recordOrRecords
    if Object.keys(recordOrRecords).length is 0
      throw new Error "can't insert empty object"
    return beget prototypes.insert, {_records: [recordOrRecords]}

  throw new TypeError 'argument must be an object or an array'

###################################################################################
# update

prototypes.update =
  sql: (mohair, escape) ->
    updates = @_updates

    unless mohair._from?
      throw new Error '.sql() of update action requires call to .table() before it'

    table = mohair._from.sql(escape)
    keys = Object.keys updates

    updatesSql = keys.map (key) ->
      escapedKey = escape key
      if implementsSqlFragmentInterface updates[key]
        "#{escapedKey} = #{updates[key].sql(escape)}"
      else
        "#{escapedKey} = ?"

    sql = "UPDATE #{table} SET #{updatesSql.join ', '}"
    if mohair._where?
      sql += " WHERE #{mohair._where.sql(escape)}"
    if mohair._returning?
      sql += " RETURNING #{mohair._returning.sql(escape)}"
    return sql

  params: (mohair) ->
    updates = @_updates

    params = []

    params = params.concat mohair._from.params()

    Object.keys(updates).forEach (key) ->
      value = updates[key]
      if implementsSqlFragmentInterface value
        params = params.concat value.params()
      else
        params.push value

    if mohair._where?
      params = params.concat mohair._where.params()
    if mohair._returning?
      params = params.concat mohair._returning.params()

    return params

factories.update = (updates) ->
  if Object.keys(updates).length is 0
    throw new Error 'nothing to update'
  beget prototypes.update,
    _updates: updates

###################################################################################
# delete

prototypes.delete =
  sql: (mohair, escape) ->
    unless mohair._from?
      throw new Error '.sql() of delete action requires call to .table() before it'

    table = mohair._from.sql(escape)
    sql = "DELETE FROM #{table}"
    if mohair._where?
      sql += " WHERE #{mohair._where.sql(escape)}"
    if mohair._returning?
      sql += " RETURNING #{mohair._returning.sql(escape)}"
    return sql

  params: (mohair) ->
    params = []
    params = params.concat mohair._from.params()
    if mohair._where?
      params = params.concat mohair._where.params()
    if mohair._returning?
      params = params.concat mohair._returning.params()
    return params

factories.delete = ->
  beget prototypes.delete

###################################################################################
# MOHAIR FLUENT API

module.exports =

###################################################################################
# core

  clone: ->
    Object.create @

  # the magic behind mohair's fluent interface:
  # prototypically inherit from `this` and set `key` to `value`

  fluent: (key, value) ->
    object = @clone()
    object[key] = value
    return object

  _escape: identity
  escape: (arg) -> @fluent '_escape', arg

  # the default action is select *
  _action: factories.select '*'

###################################################################################
# actions

  insert: (args...) -> @fluent '_action', factories.insert args...
  select: (args...) -> @fluent '_action', factories.select args...
  delete: -> @fluent '_action', factories.delete()
  update: (data) -> @fluent '_action', factories.update data

###################################################################################
# for select action only

  with: (arg) ->
    unless ('object' is typeof arg) and Object.keys(arg).length isnt 0
      throw new Error 'with must be called with an object that has at least one property'
    @fluent '_with', arg
  group: (arg) ->
    @fluent '_group', arg
  order: (arg) ->
    @fluent '_order', arg
  limit: (arg) ->
    @fluent '_limit', parseInt(arg, 10)
  offset: (arg) ->
    @fluent '_offset', parseInt(arg, 10)

###################################################################################
# from

  # supports multiple tables, subqueries and aliases
  # from: (from...) ->
  #   @fluent '_from', from...

  table: (args...) ->
    @fluent '_from', factories.fromItems args...

  _joins: []
  join: (sql, criterionArgs...) ->
    join = {sql: sql}
    join.criterion = criterion criterionArgs... if criterionArgs.length isnt 0

    next = @clone()
    # slice without arguments clones an array
    next._joins = @_joins.slice()
    next._joins.push join

    return next

###################################################################################
# where conditions

  where: (args...) ->
    where = criterion args...
    @fluent '_where', if @_where? then @_where.and(where) else where

  having: (args...) ->
    having = criterion args...
    @fluent '_having', if @_having? then @_having.and(having) else having

###################################################################################
# returning (ignored for select)

  returning: (args...) ->
    # returning can be disabled by calling without arguments
    if args.length is 0
      @fluent '_returning', null
    else
      @fluent '_returning', factories.selectOutputs args...

###################################################################################
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

###################################################################################
# helpers

  # call a one-off function as if it were part of mohair
  call: (fn, args...) ->
    fn.apply @, args

  raw: (sql, params...) ->
    criterion sql, params...

###################################################################################
# implementation of sql-fragment interface

  sql: (escape) ->
    # escape can be passed in to override the escape set on this mohair
    @_action.sql @, (escape or @_escape)

  params: ->
    @_action.params @

###################################################################################
# reexport criterion helpers

  helper: criterion.helper
