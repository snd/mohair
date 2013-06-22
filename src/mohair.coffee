criterion = require 'criterion'

rawPrototype =
    sql: -> @_sql
    params: -> @_params

isRaw = (x) ->
    ('object' is typeof x) and ('function' is typeof x.sql)

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
    _action: {verb: 'select', sql: '*'}
    _joins: []

    insert: (data) ->
        unless 'object' is typeof data
            throw new Error 'data argument must be an object'

        @fluent '_action', {verb: 'insert', data: data}

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

        @fluent '_action', {verb: 'insertMany', array: array}

    escape: (arg) ->
        @fluent '_escape', arg

    select: (sql = '*', params...) ->
        @fluent '_action', {verb: 'select', sql: sql, params: params}

    delete: ->
        @fluent '_action', {verb: 'delete'}

    update: (updates) ->
        @fluent '_action', {verb: 'update', updates: updates}

    join: (sql, criterionArgs...) ->
        join = {sql: sql}
        join.criterion = criterion criterionArgs... if criterionArgs.length isnt 0

        object = Object.create @
        # slice without arguments clones an array
        object._joins = @_joins.slice()
        object._joins.push join

        object

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
        throw new Error 'sql() requires call to table() before it' unless @_table?
        table = @_escape @_table

        switch @_action.verb
            when 'insert'
                data = @_action.data
                keys = Object.keys(data)
                escapedKeys = keys.map (key) => @_escape key
                row = keys.map (key) ->
                    if isRaw data[key]
                        data[key].sql()
                    else
                        '?'
                "INSERT INTO #{table}(#{escapedKeys.join ', '}) VALUES (#{row.join ', '})"
            when 'insertMany'
                first = @_action.array[0]
                keys = Object.keys(first)
                escapedKeys = keys.map (key) => @_escape key
                rows = @_action.array.map (data) ->
                    row = keys.map (key) ->
                        if isRaw data[key]
                            data[key].sql()
                        else
                            '?'
                    "(#{row.join ', '})"
                "INSERT INTO #{table}(#{escapedKeys.join ', '}) VALUES #{rows.join ', '}"
            when 'select'
                sql = "SELECT #{@_action.sql} FROM #{table}"
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
                keys = Object.keys @_action.updates

                updates = keys.map((k) =>
                    "#{@_escape k} = ?").join ', '
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
                data = @_action.data
                Object.keys(data).map (key) ->
                    if isRaw data[key]
                        params = params.concat data[key].params()
                    else
                        params.push data[key]
            when 'insertMany'
                firstKeys = Object.keys @_action.array[0]
                @_action.array.forEach (data) ->
                    firstKeys.forEach (key) ->
                        if isRaw data[key]
                            params = params.concat data[key].params()
                        else
                            params.push data[key]
            when 'select'
                params = params.concat @_action.params if @_action.params?

                @_joins.forEach (join) ->
                    if join.criterion?
                        params = params.concat join.criterion.params()

                params = params.concat @_where.params() if @_where?
                params.push @_limit if @_limit?
                params.push @_offset if @_offset?
            when 'update'
                updates = @_action.updates
                Object.keys(updates).forEach (key) ->
                    if isRaw updates[key]
                        params = params.concat updates[key].params()
                    else
                        params.push updates[key]
                params = params.concat @_where.params() if @_where?
            when 'delete'
                params = params.concat @_where.params() if @_where?
        params
