_ = require 'underscore'

mohair = class

    constructor: ->
        @_sql = ''
        @_params = []

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    insert: (table, object) ->
        @raw "INSERT INTO #{table} "
        @raw "(#{_.keys(object).join(', ')})"
        @raw " VALUES ("
        isFirstValue = true
        _.each _.values(object), (value) =>
            @raw ', ' if not isFirstValue
            isFirstValue = false
            if _.isFunction(value) then value() else
                @raw '?'
                @_params.push value
        @raw ");"

    # getters

    sql: -> @_sql

    params: -> @_params

module.exports = -> new mohair
