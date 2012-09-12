criterion = require 'criterion'

values = (object) ->
    vs = []
    for k, v of object
        do (k, v) -> vs.push v
    vs

Mohair = class

    # fluent
    # ======

    # returns a new Mohair instance with `key` set to `value`

    set: (key, value) ->
        object = new @constructor
        object._parent = @
        state = {}
        state[key] = value
        object._state = state
        object

    # actions
    # -------

    insert: (data) ->
        throw new Error 'missing data' unless data?
        array = if Array.isArray data then data else [data]
        throw new Error 'no records to insert' if array.length is 0

        msg = 'all records in the argument array must have the same keys.'
        keys = Object.keys array[0]
        array.forEach (item) ->
            itemKeys = Object.keys item

            throw new Error msg if itemKeys.length isnt keys.length

            keys.forEach (key, index) ->
                throw new Error msg unless key is itemKeys[index]

        @set '_action',
            verb: 'insert'
            param: array

    select: (sql = '*') -> @set '_action', {verb: 'select', param: sql}

    delete: -> @set '_action', {verb: 'delete'}

    update: (updates) -> @set '_action', {verb: 'update', param: updates}

    # select modifiers
    # ----------------

    join: (join) -> @set '_join', join

    group: (group) -> @set '_group', group

    order: (order) -> @set '_order', order

    limit: (limit) -> @set '_limit', limit

    offset: (offset) -> @set '_offset', offset

    # other
    # -----

    table: (table) -> @set '_table', table

    where: (args...) ->
        existingWhere = @get '_where'
        where = criterion args...
        @set '_where', if existingWhere? then existingWhere.and(where) else where

    # Not fluent
    # ==========

    # search for a key in the parent chain

    get: (key) ->
        return @_state[key] if @_state? and @_state[key]?
        return null if not @_parent?
        @_parent.get key

    _getAction: -> @get('_action') || {verb: 'select', param: '*'}

    sql: ->
        action = @_getAction()

        table = @get '_table'

        throw new Error 'no table' unless table?

        switch action.verb
            when 'insert'
                keys = Object.keys action.param[0]
                parts = action.param.map ->
                    questionMarks = keys.map -> '?'
                    "(#{questionMarks.join ', '})"
                "INSERT INTO #{table}(#{keys.join ', '}) VALUES #{parts.join ', '}"
            when 'select'
                join = @get '_join'
                where = @get '_where'
                group = @get '_group'
                order = @get '_order'
                limit = @get '_limit'
                offset = @get '_offset'

                sql = "SELECT #{action.param} FROM #{table}"
                sql += " #{join}" if join?
                sql += " WHERE #{where.sql()}" if where?
                sql += " GROUP BY #{group}" if group?
                sql += " ORDER BY #{order}" if order?
                sql += " LIMIT ?" if limit?
                sql += " OFFSET ?" if offset?

                sql
            when 'update'
                keys = Object.keys action.param
                where = @get '_where'

                sql = "UPDATE #{table} SET #{keys.map((k) -> "#{k} = ?").join ', '}"
                sql += " WHERE #{where.sql()}" if where?
                sql
            when 'delete'
                where = @get '_where'

                sql = "DELETE FROM #{table}"
                sql += " WHERE #{where.sql()}" if where?
                sql

    params: ->
        action = @_getAction()

        switch action.verb
            when 'insert'
                params = []
                action.param.forEach (x) ->
                    for k, v of x
                        do (k, v) -> params.push v
                params
            when 'select'
                where = @get '_where'
                limit = @get '_limit'
                offset = @get '_offset'

                params = []
                params = params.concat where.params() if where?
                params.push limit if limit?
                params.push offset if offset?
                params
            when 'update'
                where = @get '_where'

                params = values action.param
                params = params.concat where.params() if where?
                params
            when 'delete'
                where = @get '_where'

                params = []
                params = params.concat where.params() if where?
                params

module.exports = new Mohair
module.exports.Mohair = Mohair
