isRaw = (x) ->
    x? and ('object' is typeof x) and ('function' is typeof x.sql)

asRaw = (x) ->
    if isRaw x
        return x

    unless 'string' is typeof x
        throw new Exception 'raw or string expected'

    {
        sql: -> x
        params: -> []
    }

insert =
    sql: (mohair) ->
        that = this

        unless mohair._table?
            throw new Error 'sql of insert requires call to table before it'

        table = mohair._escape mohair._table
        keys = Object.keys(that._data)
        escapedKeys = keys.map (key) -> mohair._escape key
        row = keys.map (key) ->
            if isRaw that._data[key]
                that._data[key].sql()
            else
                '?'
        "INSERT INTO #{table}(#{escapedKeys.join ', '}) VALUES (#{row.join ', '})"
    params: ->
        that = this
        params = []
        Object.keys(that._data).map (key) ->
            if isRaw that._data[key]
                params = params.concat that._data[key].params()
            else
                params.push that._data[key]
        params

module.exports.insert = (data) ->
    object = Object.create insert
    object._data = data
    object

insertMany =
    sql: (mohair) ->
        that = this

        unless mohair._table?
            throw new Error 'sql of insertMany requires call to table before it'

        table = mohair._escape mohair._table
        first = that._array[0]
        keys = Object.keys(first)
        escapedKeys = keys.map (key) -> mohair._escape key
        rows = that._array.map (data) ->
            row = keys.map (key) ->
                if isRaw data[key]
                    data[key].sql()
                else
                    '?'
            "(#{row.join ', '})"
        "INSERT INTO #{table}(#{escapedKeys.join ', '}) VALUES #{rows.join ', '}"
    params: (mohair) ->
        that = this
        firstKeys = Object.keys that._array[0]
        params = []
        that._array.forEach (data) ->
            firstKeys.forEach (key) ->
                if isRaw data[key]
                    params = params.concat data[key].params()
                else
                    params.push data[key]
        params

module.exports.insertMany = (array) ->
    object = Object.create insertMany
    object._array = array
    object

select =
    sql: (mohair) ->
        that = this
        table = mohair._escape mohair._table
        sql = ''

        if mohair._with?
            sql += 'WITH '
            parts = []
            parts = Object.keys(mohair._with).map (key) ->
                key + ' AS (' + asRaw(mohair._with[key]).sql() + ')'
            sql += parts.join(', ')
            sql += ' '

        sql += "SELECT "
        parts = []
        that._selects.forEach (s) ->
            if isRaw s
                parts.push '(' + s.sql() + ')'
            else if 'object' is typeof s
                keys = Object.keys s
                if keys.length is 0
                    throw new Error 'select object must have at least one property'
                keys.forEach (key) ->
                    value = s[key]
                    if isRaw value
                        parts.push '(' + value.sql() + ') AS ' + key
                    else
                        parts.push value + ' AS ' + key
            else
                parts.push s
        sql += parts.join ', '
        if mohair._table?
            sql += " FROM #{table}"
        mohair._joins.forEach (join) ->
            sql += " #{join.sql}"
            sql += " AND (#{join.criterion.sql()})" if join.criterion?
        sql += " WHERE #{mohair._where.sql()}" if mohair._where?
        sql += " GROUP BY #{mohair._group}" if mohair._group?
        sql += " ORDER BY #{mohair._order}" if mohair._order?
        sql += " LIMIT ?" if mohair._limit?
        sql += " OFFSET ?" if mohair._offset?
        sql
    params: (mohair) ->
        that = this
        params = []

        if mohair._with?
            Object.keys(mohair._with).forEach (key) ->
                params = params.concat asRaw(mohair._with[key]).params()

        that._selects.forEach (s) ->
            if isRaw s
                params = params.concat s.params()
            else if 'object' is typeof s
                keys = Object.keys s
                if keys.length is 0
                    throw new Error 'select object must have at least one property'
                keys.forEach (key) ->
                    params = params.concat asRaw(s[key]).params()

        mohair._joins.forEach (join) ->
            if join.criterion?
                params = params.concat join.criterion.params()

        params = params.concat mohair._where.params() if mohair._where?
        params.push mohair._limit if mohair._limit?
        params.push mohair._offset if mohair._offset?
        params

module.exports.select = ->
    selects = Array.prototype.slice.call arguments
    object = Object.create select
    if selects.length is 0
        selects = ['*']
    object._selects = selects
    object

update =
    sql: (mohair) ->
        that = this

        unless mohair._table?
            throw new Error 'sql of update requires call to table before it'

        table = mohair._escape mohair._table
        keys = Object.keys that._updates

        updates = keys.map (key) ->
            escapedKey = mohair._escape key
            if isRaw that._updates[key]
                "#{escapedKey} = #{that._updates[key].sql()}"
            else
                "#{escapedKey} = ?"
        sql = "UPDATE #{table} SET #{updates.join ', '}"
        sql += " WHERE #{mohair._where.sql()}" if mohair._where?
        sql
    params: (mohair) ->
        that = this
        params = []
        Object.keys(that._updates).forEach (key) ->
            if isRaw that._updates[key]
                params = params.concat that._updates[key].params()
            else
                params.push that._updates[key]
        params = params.concat mohair._where.params() if mohair._where?
        params

module.exports.update = (updates) ->
    object = Object.create update
    object._updates = updates
    object

deletePrototype =
    sql: (mohair) ->
        that = this

        unless mohair._table?
            throw new Error 'sql of delete requires call to table before it'

        table = mohair._escape mohair._table
        sql = "DELETE FROM #{table}"
        sql += " WHERE #{mohair._where.sql()}" if mohair._where?
        sql
    params: (mohair) ->
        if mohair._where?
            mohair._where.params()
        else []

module.exports.delete = ->
    Object.create deletePrototype
