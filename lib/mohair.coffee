_ = require 'underscore'

mohair = class

    constructor: ->
        @_sql = ''
        @_params = []

    raw: (sql, params...) ->
        @_sql += sql
        @_params.push params...

    insert: (table, object) ->
        @raw "INSERT INTO #{table} (#{_.keys(object).join(', ')}) VALUES ("

        isFirstValue = true
        _.each _.values(object), (value) =>
            @raw ', ' if not isFirstValue
            isFirstValue = false
            if _.isFunction(value) then value() else
                @raw '?'
                @_params.push value

        @raw ");\n"

    equal: (column, bindingOrFunction) ->
        @raw "#{column} = "
        if _.isFunction(bindingOrFunction) then bindingOrFunction() else
            @raw '?'
            @_params.push bindingOrFunction

    where: (inner) ->
        @raw " WHERE "
        inner()

    # getters

    sql: -> @_sql

    params: -> @_params

module.exports = -> new mohair
