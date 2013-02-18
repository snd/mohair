criterion = require 'criterion'

values = (object) ->
    vs = []
    for k, v of object
        do (k, v) -> vs.push v
    vs

module.exports =

    set: (key, value) ->
        object = Object.create @
        object[key] = value
        object

    insert: (data) ->
        throw new Error 'missing data' unless data?
        dataArray = if Array.isArray data then data else [data]
        throw new Error 'no records to insert' if dataArray.length is 0

        msg = 'all records in the argument array must have the same keys.'
        keysOfFirstRecord = Object.keys dataArray[0]
        dataArray.forEach (item) ->
            itemKeys = Object.keys item

            throw new Error msg if itemKeys.length isnt keysOfFirstRecord.length

            keysOfFirstRecord.forEach (key, index) ->
                throw new Error msg unless key is itemKeys[index]

        @set '_action', {verb: 'insert', param: dataArray}

    _escape: (string) -> string
    _action: {verb: 'select', param: '*'}
    _joins: []

    escape: (arg) -> @set '_escape', arg

    select: (sql = '*', args...) -> @set '_action', {verb: 'select', param: sql, args: args}

    delete: -> @set '_action', {verb: 'delete'}

    update: (updates) -> @set '_action', {verb: 'update', param: updates}

    join: (sql, criterionArgs...) ->
        object = Object.create @
        # slice without arguments clones an array
        object._joins = @_joins.slice()
        join = {sql: sql}
        join.criterion = criterion criterionArgs... if criterionArgs.length isnt 0
        object._joins.push join
        object

    group: (arg) -> @set '_group', arg
    order: (arg) -> @set '_order', arg
    limit: (arg) -> @set '_limit', parseInt arg, 10
    offset: (arg) -> @set '_offset', parseInt arg, 10

    table: (table) -> @set '_table', table

    where: (args...) ->
        where = criterion args...
        @set '_where', if @_where? then @_where.and(where) else where

    sql: ->
        throw new Error 'sql() requires call to table() before it' unless @_table?
        table = @_escape @_table

        switch @_action.verb
            when 'insert'
                keys = Object.keys(@_action.param[0]).map (key) => @_escape key
                parts = @_action.param.map ->
                    questionMarks = keys.map -> '?'
                    "(#{questionMarks.join ', '})"
                "INSERT INTO #{table}(#{keys.join ', '}) VALUES #{parts.join ', '}"
            when 'select'
                sql = "SELECT #{@_action.param} FROM #{table}"
                @_joins.forEach (join) ->
                    sql += " #{join.sql}"
                    sql += " AND (#{join.criterion.sql()})" if join.criterion?
                sql += " WHERE #{@_where.sql()}" if @_where?
                sql += " GROUP BY #{@_group}" if @_group?
                sql += " ORDER BY #{@_order}" if @_order?
                sql += " LIMIT ?" if @_limit?
                sql += " OFFSET ?" if @_offset?
                sql
            when 'update'
                keys = Object.keys @_action.param

                updates = keys.map((k) => "#{@_escape k} = ?").join ', '
                sql = "UPDATE #{table} SET #{updates}"
                sql += " WHERE #{@_where.sql()}" if @_where?
                sql
            when 'delete'
                sql = "DELETE FROM #{table}"
                sql += " WHERE #{@_where.sql()}" if @_where?
                sql

    params: ->
        params = []
        switch @_action.verb
            when 'insert'
                @_action.param.forEach (x) -> params = params.concat values x
            when 'select'
                params = params.concat @_action.args if @_action.args?
                @_joins.forEach (join) ->
                    if join.criterion?
                        params = params.concat join.criterion.params()

                params = params.concat @_where.params() if @_where?
                params.push @_limit if @_limit?
                params.push @_offset if @_offset?
            when 'update'
                params = params.concat values @_action.param
                params = params.concat @_where.params() if @_where?
            when 'delete'
                params = params.concat @_where.params() if @_where?
        params
