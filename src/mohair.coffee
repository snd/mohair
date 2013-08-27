criterion = require 'criterion'

actions = require './actions'

rawPrototype =
    sql: -> @_sql
    params: -> @_params

module.exports =
    raw: (sql, params...) ->
        object = Object.create rawPrototype
        object._sql = sql
        object._params = params
        object

    fluent: (key, value) ->
        object = Object.create @
        object[key] = value
        object

    _escape: (string) -> string
    _action: actions.select '*'
    _joins: []

    insert: (data) ->
        unless 'object' is typeof data
            throw new Error 'data argument must be an object'

        @fluent '_action', actions.insert data

    insertMany: (array) ->
        unless Array.isArray array
            throw new Error 'array argument must be an array'

        throw new Error 'array argument is empty - no records to insert' if array.length is 0

        msg = 'all records in the argument array must have the same keys.'
        keysOfFirstRecord = Object.keys array[0]
        array.forEach (data) ->
            keys = Object.keys data

            throw new Error msg if keys.length isnt keysOfFirstRecord.length

            keysOfFirstRecord.forEach (key) ->
                throw new Error msg unless data[key]?

        @fluent '_action', actions.insertMany array

    escape: (arg) ->
        @fluent '_escape', arg

    select: ->
        @fluent '_action', actions.select.apply null, arguments

    delete: ->
        @fluent '_action', actions.delete()

    update: (updates) ->
        @fluent '_action', actions.update updates

    join: (sql, criterionArgs...) ->
        join = {sql: sql}
        join.criterion = criterion criterionArgs... if criterionArgs.length isnt 0

        object = Object.create @
        # slice without arguments clones an array
        object._joins = @_joins.slice()
        object._joins.push join

        object

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

    table: (table) ->
        @fluent '_table', table

    where: (args...) ->
        where = criterion args...
        @fluent '_where', if @_where? then @_where.and(where) else where

    sql: ->
        @_action.sql @

    params: ->
        @_action.params @
