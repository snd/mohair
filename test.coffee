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

    'update':
        'bindings': (test) ->
            changes =
                name: 'Even more amazing project'
                hidden: true

            m = mohair()
            m.update 'project', changes, {id: 7}

            test.equals m.sql(), 'UPDATE project SET name = ?, hidden = ? WHERE id = ?;\n'
            test.deepEqual m.params(), ['Even more amazing project', true, 7]
            test.done()

        'bindings and raw': (test) ->
            m = mohair()

            changes =
                name: 'Even more amazing project'
                updated_on: -> m.raw 'NOW()'

            m.update 'project', changes, {id: 7}

            test.equals m.sql(), 'UPDATE project SET name = ?, updated_on = NOW() WHERE id = ?;\n'
            test.deepEqual m.params(), ['Even more amazing project', 7]
            test.done()

    'remove': (test) ->
        m = mohair()

        m.remove 'project', {id: 7, hidden: true}

        test.equals m.sql(), 'DELETE FROM project WHERE id = ? AND hidden = ?;\n'
        test.deepEqual m.params(), [7, true]
        test.done()

    'transaction': (test) ->
        m = mohair()

        m.transaction ->
            m.remove 'project', {id: 7}
            m.update 'project', {name: 'New name'}, {id: 8}

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

            m.select 'project', ['name', 'id'], {hidden: true}

            test.equals m.sql(), 'SELECT name, id FROM project WHERE hidden = ?;\n'
            test.deepEqual m.params(), [true]
            test.done()

        'join, groupBy and orderBy': (test) ->
            m = mohair()

            m.select 'project', ['count(task.id) AS taskCount', 'project.*'], ->
                m.where {id: 7}
                m.leftJoin 'task', 'project.id' , 'task.project_id'
                m.groupBy 'project.id'
                m.orderBy 'project.created_on DESC'

            test.equals m.sql(), 'SELECT count(task.id) AS taskCount, project.* FROM project WHERE id = ? LEFT JOIN task ON project.id = task.project_id GROUP BY project.id ORDER BY project.created_on DESC;\n'
            test.deepEqual m.params(), [7]
            test.done()

    'query':

        'toplevel': (test) ->
            m = mohair()

            m.query
                project_id: 6
                hidden: true
                name: -> m.quoted 'Another Project'

            test.equals m.sql(), "project_id = ? AND hidden = ? AND name = 'Another Project'"
            test.deepEqual m.params(), [6, true]
            test.done()

        '$or': (test) ->
            m = mohair()

            m.query
                $or: [
                    {project_id: 6}
                    {hidden: true}
                    {name: -> m.quoted 'Another Project'}
                ]

            test.equals m.sql(), "(project_id = ? OR hidden = ? OR name = 'Another Project')"
            test.deepEqual m.params(), [6, true]
            test.done()

        'or and and': (test) ->
            m = mohair()

            m.query
                project_id: 6
                $or: [
                    {hidden: true}
                    {$and: [
                        {name: -> m.quoted 'Another Project'}
                        {owner_id: 8}
                    ]}
                ]

            test.equals m.sql(), "project_id = ? AND (hidden = ? OR name = 'Another Project' AND owner_id = ?)"
            test.deepEqual m.params(), [6, true, 8]
            test.done()

        'comparison operators': (test) ->
            m = mohair()

            m.query
                project_id: {$lt: 6}
                $or: [
                    {hidden: true}
                    {$and: [
                        {name: {$ne: -> m.quoted 'Another Project'}}
                        {owner_id: {$gte: 8}}
                    ]}
                ]

            test.equals m.sql(), "project_id < ? AND (hidden = ? OR name != 'Another Project' AND owner_id >= ?)"
            test.deepEqual m.params(), [6, true, 8]
            test.done()

        'nested query': (test) ->
            m = mohair()

            m.query
                id: 7
                $or: [
                    {owner_id: 10}
                    $and: [
                        {cost: {$gt: 500}}
                        {cost: {$lt: 1000}}
                    ]
                ]

            test.equals m.sql(), "id = ? AND (owner_id = ? OR cost > ? AND cost < ?)"
            test.deepEqual m.params(), [7, 10, 500, 1000]
            test.done()

        '$in': (test) ->
            m = mohair()

            m.query
                id: {$in: [3, 5, 8, 9]}
                owner_id: {$in: [10]}
                name: {$in: ['Ann', 'Rick']}

            test.equals m.sql(), 'id IN (?, ?, ?, ?) AND owner_id IN (?) AND name IN (?, ?)'
            test.deepEqual m.params(), [3, 5, 8, 9, 10, 'Ann', 'Rick']
            test.done()

        '$not': (test) ->
            m = mohair()

            m.query
                $not:
                    id: 9
                    name: 'Ann'

            test.equals m.sql(), 'NOT (id = ? AND name = ?)'
            test.deepEqual m.params(), [9, 'Ann']
            test.done()

        '$not and $or': (test) ->
            m = mohair()

            m.query
                $or: [
                    {name: 'Ann'}
                    {$not: {
                        id: 9
                        name: 'Rick'
                    }}
                ]

            test.equals m.sql(), '(name = ? OR NOT (id = ? AND name = ?))'
            test.deepEqual m.params(), ['Ann', 9, 'Rick']
            test.done()

        '$nor': (test) ->
            m = mohair()

            m.query
                $nor: [
                    {name: 'Ann'}
                    {
                        id: 9
                        name: 'Rick'
                    }
                ]

            test.equals m.sql(), 'NOT (name = ? OR id = ? AND name = ?)'
            test.deepEqual m.params(), ['Ann', 9, 'Rick']
            test.done()

        '$nin': (test) ->
            m = mohair()

            m.query
                id: {$nin: [3, 5, 8, 9]}
                owner_id: {$nin: [10]}
                name: {$nin: ['Ann', 'Rick']}

            test.equals m.sql(), 'id NOT IN (?, ?, ?, ?) AND owner_id NOT IN (?) AND name NOT IN (?, ?)'
            test.deepEqual m.params(), [3, 5, 8, 9, 10, 'Ann', 'Rick']
            test.done()

        'string as value in query is not interpreted as test': (test) ->
            m = mohair()

            m.query
                $or: [
                    {id: 'foo'}
                    {foo: 'id'}
                ]

            test.equals m.sql(), '(id = ? OR foo = ?)'
            test.deepEqual m.params(), ['foo', 'id']
            test.done()

        'invalid $or query throws': (test) ->
            m = mohair()

            test.throws ->

                m.query
                    $or:
                        id: 'foo'
                        foo: 'id'

            test.done()
