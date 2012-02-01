mohair = class

    constructor: ->
        @_sql = ''
        @_params = []

    raw: (sql, params...) =>
        @_sql += sql
        @_params.push params...

    sql: => @_sql

    params: => @_params

module.exports = -> new mohair
