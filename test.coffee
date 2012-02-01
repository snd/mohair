mohair = require './lib/mohair'

module.exports =
    'raw':
        'without bindings': (test) ->
            string = 'SELECT * FROM project;'

            m = mohair()
            m.raw string

            test.equals m.sql(), string
            test.done()

        'with bindings': (test) ->
            string = 'SELECT * FROM project WHERE id = ? AND owner_id = ?;'

            m = mohair()
            m.raw string, 7, 4

            test.equals m.sql(), string
            test.deepEqual m.params(), [7, 4]
            test.done()

        'twice': (test) ->
            m = mohair()
            m.raw 'SELECT * FROM project WHERE id = ?;', 7
            m.raw 'SELECT * FROM project WHERE id = ?;', 4

            test.equals m.sql(), 'SELECT * FROM project WHERE id = ?;SELECT * FROM project WHERE id = ?;'
            test.deepEqual m.params(), [7, 4]
            test.done()

    'insert':

        'bindings': (test) ->
            m = mohair()
            m.insert 'project',
                name: 'Amazing Project'
                owner_id: 5
                hidden: false

            test.equals m.sql(), 'INSERT INTO project (name, owner_id, hidden) VALUES (?, ?, ?);\n'
            test.deepEqual m.params(), ['Amazing Project', 5, false]
            test.done()

        'bindings and raw': (test) ->
            m = mohair()
            m.insert 'project',
                name: 'Another Project'
                created_on: -> m.raw 'NOW()'

            test.equals m.sql(), 'INSERT INTO project (name, created_on) VALUES (?, NOW());\n'
            test.deepEqual m.params(), ['Another Project']
            test.done()

    'equal':

        'bindigns': (test) ->
            m = mohair()
            m.equal 'id', 7

            test.equals m.sql(), 'id = ?'
            test.deepEqual m.params(), [7]
            test.done()

        'raw': (test) ->
            m = mohair()
            m.equal 'id', -> m.raw 'owner_id'

            test.equals m.sql(), 'id = owner_id'
            test.deepEqual m.params(), []
            test.done()
