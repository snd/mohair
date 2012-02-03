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

        'multiple': (test) ->
            m = mohair()
            m.insert 'project', {
                name: 'First Project'
                created_on: -> m.raw 'NOW()'
            }, {
                name: 'Second Project'
                created_on: '1988.09.11'
            }

            test.equals m.sql(), 'INSERT INTO project (name, created_on) VALUES (?, NOW()), (?, ?);\n'
            test.deepEqual m.params(), ['First Project', 'Second Project', '1988.09.11']
            test.done()

    'Is':

        'bindings': (test) ->
            m = mohair()
            m.Is 'id', 7

            test.equals m.sql(), 'id = ?'
            test.deepEqual m.params(), [7]
            test.done()

        'raw': (test) ->
            m = mohair()
            m.Is 'id', -> m.raw 'owner_id'

            test.equals m.sql(), 'id = owner_id'
            test.deepEqual m.params(), []
            test.done()

    'update':
        'bindings': (test) ->
            changes =
                name: 'Even more amazing project'
                hidden: true

            m = mohair()
            m.update 'project', changes, ->
                m.where -> m.Is 'id', 7

            test.equals m.sql(), 'UPDATE project SET name = ?, hidden = ? WHERE id = ?;\n'
            test.deepEqual m.params(), ['Even more amazing project', true, 7]
            test.done()

        'bindings and raw': (test) ->
            m = mohair()

            changes =
                name: 'Even more amazing project'
                updated_on: -> m.raw 'NOW()'

            m.update 'project', changes, ->
                m.where -> m.Is 'id', 7

            test.equals m.sql(), 'UPDATE project SET name = ?, updated_on = NOW() WHERE id = ?;\n'
            test.deepEqual m.params(), ['Even more amazing project', 7]
            test.done()

    'remove': (test) ->
        m = mohair()

        m.remove 'project', ->
            m.where ->
                m.Is 'id', 7
                m.And()
                m.Is 'hidden', true

        test.equals m.sql(), 'DELETE FROM project WHERE id = ? AND hidden = ?;\n'
        test.deepEqual m.params(), [7, true]
        test.done()

    'transaction': (test) ->
        m = mohair()

        m.transaction ->
            m.remove 'project', ->
                m.where -> m.Is 'id', 7
            m.update 'project', {name: 'New name'}, ->
                m.where -> m.Is 'id', 8

        test.equals m.sql(), 'START TRANSACTION;\nDELETE FROM project WHERE id = ?;\nUPDATE project SET name = ? WHERE id = ?;\nCOMMIT;\n'
        test.deepEqual m.params(), [7, 'New name', 8]
        test.done()

    'select':

        'implicit star': (test) ->
            m = mohair()

            m.select 'project'

            test.equals m.sql(), 'SELECT * FROM project;\n'
            test.deepEqual m.params(), []
            test.done()

        'explicit column list and where clause': (test) ->
            m = mohair()

            m.select 'project', ['name', 'id'], ->
                m.where -> m.Is 'hidden', true

            test.equals m.sql(), 'SELECT name, id FROM project WHERE hidden = ?;\n'
            test.deepEqual m.params(), [true]
            test.done()

        'join, groupBy and orderBy': (test) ->
            m = mohair()

            m.select 'project', ['count(task.id) AS taskCount', 'project.*'], ->
                m.leftJoin 'task', 'project.id' , 'task.project_id'
                m.groupBy 'project.id'
                m.orderBy 'project.created_on DESC'

            test.equals m.sql(), 'SELECT count(task.id) AS taskCount, project.* FROM project LEFT JOIN task ON project.id = task.project_id GROUP BY project.id ORDER BY project.created_on DESC;\n'
            test.deepEqual m.params(), []
            test.done()
