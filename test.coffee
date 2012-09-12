mohair = require './index'

module.exports =

    'throw on':

        'insert without table': (test) ->
            q = mohair.insert {name: 'foo', email: 'foo@example.com'}
            test.throws -> q.sql()

            test.done()

        'create multiple records without matching keys': (test) ->
            test.throws ->
                mohair.table('user').insert [
                    {name: 'foo', email: 'foo@example.com'}
                    {name: 'bar'}
                ]

            test.throws ->
                mohair.table('user').insert [
                    {name: 'foo', email: 'foo@example.com'}
                    {name: 'bar', id: 9}
                ]

            test.done()

    'insert':

        'a record': (test) ->
            q = mohair.table('user').insert {name: 'foo', user_id: 5}

            test.equal q.sql(), 'INSERT INTO user(name, user_id) VALUES (?, ?)'
            test.deepEqual q.params(), ['foo', 5]

            test.done()

        'multiple records': (test) ->
            q = mohair.table('user').insert [
                {name: 'foo', email: 'foo@example.com'}
                {name: 'bar', email: 'bar@example.com'}
                {name: 'baz', email: 'baz@example.com'}
            ]

            test.equal q.sql(),
                'INSERT INTO user(name, email) VALUES (?, ?), (?, ?), (?, ?)'
            test.deepEqual q.params(),
                ['foo', 'foo@example.com', 'bar', 'bar@example.com', 'baz', 'baz@example.com']

            test.done()

    'delete':

        'without criteria': (test) ->
            q = mohair.table('user').delete()

            test.equal q.sql(), 'DELETE FROM user'
            test.deepEqual q.params(), []

            test.done()

        'with criteria': (test) ->
            q = mohair.table('user')
                .delete()
                .where('x BETWEEN ? AND ?', 50, 55)
                .where($or: {x: 10, y: 6})

            test.equal q.sql(), 'DELETE FROM user WHERE x BETWEEN ? AND ? AND (x = ?) OR (y = ?)'
            test.deepEqual q.params(), [50, 55, 10, 6]

            test.done()

    'update':

        'without criteria': (test) ->
            q = mohair.table('user').update {name: 'bar', email: 'bar@example.com'}

            test.equal q.sql(), 'UPDATE user SET name = ?, email = ?'
            test.deepEqual q.params(), ['bar', 'bar@example.com']

            test.done()

        'with criteria': (test) ->
            q = mohair.table('user')
                .where(id: 3, x: 5)
                .update {name: 'bar', email: 'bar@example.com'}

            test.equal q.sql(), 'UPDATE user SET name = ?, email = ? WHERE id = ? AND x = ?'
            test.deepEqual q.params(), ['bar', 'bar@example.com', 3, 5]

            test.done()

    'select':

        'default is select *': (test) ->
            q = mohair.table('user')

            test.equal q.sql(), 'SELECT * FROM user'
            test.deepEqual q.params(), []

            test.done()

        'all fields': (test) ->
            q = mohair.table('user').select()

            test.equal q.sql(), 'SELECT * FROM user'
            test.deepEqual q.params(), []

            test.done()

        'specific fields': (test) ->
            q = mohair.table('user').select('name, timestamp AS created_at')

            test.equal q.sql(), 'SELECT name, timestamp AS created_at FROM user'
            test.deepEqual q.params(), []

            test.done()

        'with criteria': (test) ->
            q = mohair.table('user').where(id: 3).select()

            test.equal q.sql(), 'SELECT * FROM user WHERE id = ?'
            test.deepEqual q.params(), [3]

            test.done()

        'criteria are anded together': (test) ->
            q = mohair.table('user').where(id: 3).where('name = ?', 'foo').select()

            test.equal q.sql(), 'SELECT * FROM user WHERE id = ? AND name = ?'
            test.deepEqual q.params(), [3, 'foo']

            test.done()

        'order': (test) ->
            q = mohair.table('user').order('created DESC, name ASC')

            test.equal q.sql(), 'SELECT * FROM user ORDER BY created DESC, name ASC'
            test.deepEqual q.params(), []

            test.done()

        'limit': (test) ->
            q = mohair.table('user').limit(10)

            test.equal q.sql(), 'SELECT * FROM user LIMIT ?'
            test.deepEqual q.params(), [10]

            test.done()

        'offset': (test) ->
            q = mohair.table('user').offset(5)

            test.equal q.sql(), 'SELECT * FROM user OFFSET ?'
            test.deepEqual q.params(), [5]

            test.done()

        'join': (test) ->
            q = mohair.table('user')
                .join('JOIN project ON user.id = project.user_id')

            test.equal q.sql(), 'SELECT * FROM user JOIN project ON user.id = project.user_id'
            test.deepEqual q.params(), []

            test.done()

        'group': (test) ->
            q = mohair.table('user')
                .select('user.*, count(project.id) AS project_count')
                .join('JOIN project ON user.id = project.user_id')
                .group('user.id')

            test.equal q.sql(), 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id GROUP BY user.id'
            test.deepEqual q.params(), []

            test.done()

        'everything together': (test) ->
            q = mohair.table('user')
                .select('user.*, count(project.id) AS project_count')
                .where(id: 3)
                .where('name = ?', 'foo')
                .join('JOIN project ON user.id = project.user_id')
                .group('user.id')
                .order('created DESC, name ASC')
                .limit(10)
                .offset(20)

            test.equal q.sql(), 'SELECT user.*, count(project.id) AS project_count FROM user JOIN project ON user.id = project.user_id WHERE id = ? AND name = ? GROUP BY user.id ORDER BY created DESC, name ASC LIMIT ? OFFSET ?'
            test.deepEqual q.params(), [3, 'foo', 10, 20]

            test.done()

    'actions overwrite previous actions': (test) ->
        chain = mohair.table('user')
            .where(id: 3)
            .select('name')

        query = chain.insert(name: 'foo').table('project')

        test.equal chain.sql(), 'SELECT name FROM user WHERE id = ?'
        test.deepEqual chain.params(), [3]

        test.equal query.sql(), 'INSERT INTO project(name) VALUES (?)'
        test.deepEqual query.params(), ['foo']

        test.done()

    'immutability': (test) ->
        visible = mohair.table('project').where(is_visible: true)

        updateQuery = visible.update({name: 'i am visible'}).where(id: 3)
        test.equal updateQuery.sql(),
            'UPDATE project SET name = ? WHERE is_visible = ? AND id = ?'
        test.deepEqual updateQuery.params(), ['i am visible', true, 3]

        deleteQuery = visible.where({name: 'foo'}).delete()

        test.equal deleteQuery.sql(),
            'DELETE FROM project WHERE is_visible = ? AND name = ?'
        test.deepEqual deleteQuery.params(), [true, 'foo']

        test.done()
