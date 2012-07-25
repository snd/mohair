mohair = require './index'

module.exports =
    'mysql':

        'raw':

            'without bindings': (test) ->
                string = 'SELECT * FROM `project`;'

                m = mohair()
                m.raw string

                test.equals m.sql(), string
                test.done()

            'with bindings': (test) ->
                string = 'SELECT * FROM `project` WHERE `id` = ? AND `owner_id` = ?;'

                m = mohair()
                m.raw string, 7, 4

                test.equals m.sql(), string
                test.deepEqual m.params(), [7, 4]
                test.done()

            'twice': (test) ->
                m = mohair()
                m.raw 'SELECT * FROM `project` WHERE `id` = ?;', 7
                m.raw 'SELECT * FROM `project` WHERE `id` = ?;', 4

                test.equals m.sql(), 'SELECT * FROM `project` WHERE `id` = ?;SELECT * FROM `project` WHERE `id` = ?;'
                test.deepEqual m.params(), [7, 4]
                test.done()

        'insert':

            'empty': (test) ->
                m = mohair()
                m.insert 'project', []

                test.equals m.sql(), 'INSERT INTO `project` () VALUES ();\n'
                test.deepEqual m.params(), []
                test.done()

            'bindings': (test) ->
                m = mohair()
                m.insert 'project',
                    name: 'Amazing Project'
                    owner_id: 5
                    hidden: false

                test.equals m.sql(), 'INSERT INTO `project` (`name`, `owner_id`, `hidden`) VALUES (?, ?, ?);\n'
                test.deepEqual m.params(), ['Amazing Project', 5, false]
                test.done()

            'bindings and raw': (test) ->
                m = mohair()
                m.insert 'project',
                    name: 'Another Project'
                    created_on: -> m.raw 'NOW()'

                test.equals m.sql(), 'INSERT INTO `project` (`name`, `created_on`) VALUES (?, NOW());\n'
                test.deepEqual m.params(), ['Another Project']
                test.done()

            'multiple': (test) ->
                m = mohair()
                m.insert 'project', [
                    {
                        name: 'First Project'
                        created_on: -> m.raw 'NOW()'
                    }
                    {
                        name: 'Second Project'
                        created_on: '1988.09.11'
                    }
                ]

                test.equals m.sql(), 'INSERT INTO `project` (`name`, `created_on`) VALUES (?, NOW()), (?, ?);\n'
                test.deepEqual m.params(), ['First Project', 'Second Project', '1988.09.11']
                test.done()

        'update':

            'bindings': (test) ->
                changes =
                    name: 'Even more amazing project'
                    hidden: true

                m = mohair()
                m.update 'project', changes, {id: 7}

                test.equals m.sql(), 'UPDATE `project` SET `name` = ?, `hidden` = ? WHERE `id` = ?;\n'
                test.deepEqual m.params(), ['Even more amazing project', true, 7]
                test.done()

            'bindings and raw': (test) ->
                m = mohair()

                changes =
                    name: 'Even more amazing project'
                    updated_on: -> m.raw 'NOW()'

                m.update 'project', changes, {id: 7}

                test.equals m.sql(), 'UPDATE `project` SET `name` = ?, `updated_on` = NOW() WHERE `id` = ?;\n'
                test.deepEqual m.params(), ['Even more amazing project', 7]
                test.done()

        'delete': (test) ->
            m = mohair()

            m.delete 'project', {id: 7, hidden: true}

            test.equals m.sql(), 'DELETE FROM `project` WHERE `id` = ? AND `hidden` = ?;\n'
            test.deepEqual m.params(), [7, true]
            test.done()

        'transaction': (test) ->
            m = mohair()

            m.transaction ->
                m.delete 'project', {id: 7}
                m.update 'project', {name: 'New name'}, {id: 8}

            test.equals m.sql(), 'BEGIN;\nDELETE FROM `project` WHERE `id` = ?;\nUPDATE `project` SET `name` = ? WHERE `id` = ?;\nCOMMIT;\n'
            test.deepEqual m.params(), [7, 'New name', 8]
            test.done()

        'select':

            'implicit star': (test) ->
                m = mohair()

                m.select 'project'

                test.equals m.sql(), 'SELECT * FROM `project`;\n'
                test.deepEqual m.params(), []
                test.done()

            'explicit column list and where clause': (test) ->
                m = mohair()

                m.select 'project', ['name', 'id'], {hidden: true}

                test.equals m.sql(), 'SELECT name, id FROM `project` WHERE `hidden` = ?;\n'
                test.deepEqual m.params(), [true]
                test.done()

            'join, groupBy and orderBy': (test) ->
                m = mohair()

                m.select 'project', ['count(task.id) AS taskCount', 'project.*'], ->
                    m.where {id: 7}
                    m.leftJoin 'task', 'project.id' , 'task.project_id'
                    m.groupBy 'project.id'
                    m.orderBy 'project.created_on'
                    m.limit 5
                    m.skip -> m.raw '6'

                test.equals m.sql(), 'SELECT count(task.id) AS taskCount, project.* FROM `project` WHERE `id` = ? LEFT JOIN `task` ON `project`.`id` = `task`.`project_id` GROUP BY `project`.`id` ORDER BY `project`.`created_on` LIMIT ? SKIP 6;\n'
                test.deepEqual m.params(), [7, 5]
                test.done()

        'orderBy':

            'one string': (test) ->
                m = mohair()
                m.orderBy 'foo'
                test.equals m.sql(), ' ORDER BY `foo`'
                test.done()

            'one asc': (test) ->
                m = mohair()
                m.orderBy {$asc: 'foo'}
                test.equals m.sql(), ' ORDER BY `foo` ASC'
                test.done()

            'one desc': (test) ->
                m = mohair()
                m.orderBy {$desc: 'foo'}
                test.equals m.sql(), ' ORDER BY `foo` DESC'
                test.done()

            'one invalid': (test) ->
                m = mohair()
                test.throws ->
                    m.orderBy {foo: 'foo'}
                test.done()

            'two strings': (test) ->
                m = mohair()
                m.orderBy ['foo', 'bar']
                test.equals m.sql(), ' ORDER BY `foo`, `bar`'
                test.done()

            'string and asc': (test) ->
                m = mohair()
                m.orderBy ['foo', {$asc: 'bar'}]
                test.equals m.sql(), ' ORDER BY `foo`, `bar` ASC'
                test.done()

            'asc and desc': (test) ->
                m = mohair()
                m.orderBy [{$asc: 'foo'}, {$desc: 'bar'}]
                test.equals m.sql(), ' ORDER BY `foo` ASC, `bar` DESC'
                test.done()

            'one of two invalid': (test) ->
                m = mohair()
                test.throws ->
                    m.orderBy [{foo: 'foo'}, {$asc: 'bar'}]
                test.done()

        'query':

            'toplevel': (test) ->
                m = mohair()

                m.query
                    'project.id': 6
                    hidden: true
                    name: -> m.quoted 'Another Project'

                test.equals m.sql(), "`project`.`id` = ? AND `hidden` = ? AND `name` = 'Another Project'"
                test.deepEqual m.params(), [6, true]
                test.done()

            '$or': (test) ->
                m = mohair()

                m.query
                    $or: [
                        {'project.id': 6}
                        {hidden: true}
                        {name: -> m.quoted 'Another Project'}
                    ]

                test.equals m.sql(), "(`project`.`id` = ? OR `hidden` = ? OR `name` = 'Another Project')"
                test.deepEqual m.params(), [6, true]
                test.done()

            'or and and': (test) ->
                m = mohair()

                m.query
                    'project.id': 6
                    $or: [
                        {hidden: true}
                        {$and: [
                            {name: -> m.quoted 'Another Project'}
                            {owner_id: 8}
                        ]}
                    ]

                test.equals m.sql(), "`project`.`id` = ? AND (`hidden` = ? OR `name` = 'Another Project' AND `owner_id` = ?)"
                test.deepEqual m.params(), [6, true, 8]
                test.done()

            'comparison operators': (test) ->
                m = mohair()

                m.query
                    'project.id': {$lt: 6}
                    $or: [
                        {hidden: true}
                        {$and: [
                            {name: {$ne: -> m.quoted 'Another Project'}}
                            {'owner.id': {$gte: 8}}
                        ]}
                    ]

                test.equals m.sql(), "`project`.`id` < ? AND (`hidden` = ? OR `name` != 'Another Project' AND `owner`.`id` >= ?)"
                test.deepEqual m.params(), [6, true, 8]
                test.done()

            'nested query': (test) ->
                m = mohair()

                m.query
                    id: 7
                    $or: [
                        {'owner.id': 10}
                        $and: [
                            {cost: {$gt: 500}}
                            {cost: {$lt: 1000}}
                        ]
                    ]

                test.equals m.sql(), "`id` = ? AND (`owner`.`id` = ? OR `cost` > ? AND `cost` < ?)"
                test.deepEqual m.params(), [7, 10, 500, 1000]
                test.done()

            '$in': (test) ->
                m = mohair()

                m.query
                    id: {$in: [3, 5, 8, 9]}
                    'owner.id': {$in: [10]}
                    name: {$in: ['Ann', 'Rick']}

                test.equals m.sql(), '`id` IN (?, ?, ?, ?) AND `owner`.`id` IN (?) AND `name` IN (?, ?)'
                test.deepEqual m.params(), [3, 5, 8, 9, 10, 'Ann', 'Rick']
                test.done()

            '$not': (test) ->
                m = mohair()

                m.query
                    $not:
                        id: 9
                        name: 'Ann'

                test.equals m.sql(), 'NOT (`id` = ? AND `name` = ?)'
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

                test.equals m.sql(), '(`name` = ? OR NOT (`id` = ? AND `name` = ?))'
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

                test.equals m.sql(), 'NOT (`name` = ? OR `id` = ? AND `name` = ?)'
                test.deepEqual m.params(), ['Ann', 9, 'Rick']
                test.done()

            '$nin': (test) ->
                m = mohair()

                m.query
                    id: {$nin: [3, 5, 8, 9]}
                    'owner.id': {$nin: [10]}
                    name: {$nin: ['Ann', 'Rick']}

                test.equals m.sql(), '`id` NOT IN (?, ?, ?, ?) AND `owner`.`id` NOT IN (?) AND `name` NOT IN (?, ?)'
                test.deepEqual m.params(), [3, 5, 8, 9, 10, 'Ann', 'Rick']
                test.done()

            'string as value in query is not interpreted as test': (test) ->
                m = mohair()

                m.query
                    $or: [
                        {id: 'foo'}
                        {foo: 'id'}
                    ]

                test.equals m.sql(), '(`id` = ? OR `foo` = ?)'
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

        'upsert': (test) ->
            m = mohair()
            m.upsert 'project', {id: 5, name: 'Amazing Project'},
                owner_id: -> m.raw 'LAST_INSERT_ID()'
                hidden: false

            test.equals m.sql(), 'INSERT INTO `project` (`id`, `name`, `owner_id`, `hidden`) VALUES (?, ?, LAST_INSERT_ID(), ?) ON DUPLICATE KEY UPDATE `id` = ?, `name` = ?, `owner_id` = LAST_INSERT_ID(), `hidden` = ?;\n'
            test.deepEqual m.params(), [5, 'Amazing Project', false, 5, 'Amazing Project', false]
            test.done()

    'postgres':

        'complex query': (test) ->

            m = mohair.postgres()

            m.select 'project', ['count(task.id) AS taskCount', 'project.*'], ->
                m.where {$or: [{id: 7}, {foo: 'id'}]}
                m.leftJoin 'task', 'project.id' , 'task.project_id'
                m.groupBy 'project.id'
                m.orderBy 'project.created_on'
                m.limit 5
                m.skip -> m.raw '6'

            test.equals m.sql(), 'SELECT count(task.id) AS taskCount, project.* FROM "project" WHERE ("id" = $1 OR "foo" = $2) LEFT JOIN "task" ON "project"."id" = "task"."project_id" GROUP BY "project"."id" ORDER BY "project"."created_on" LIMIT $3 SKIP 6;\n'
            test.deepEqual m.params(), [7, 'id', 5]
            test.done()

        'upsert': (test) ->

            m = mohair.postgres()

            m.upsert 'project', {id: 5, name: 'Amazing Project'},
                owner_id: -> m.raw 'LAST_INSERT_ID()'
                hidden: false

            expected = 'UPDATE "project" SET "id" = $1, "name" = $2, "owner_id" = LAST_INSERT_ID(), "hidden" = $3 WHERE "id" = $4 AND "name" = $5;\nINSERT INTO "project" ("id", "name", "owner_id", "hidden") SELECT $6, $7, LAST_INSERT_ID(), $8 WHERE NOT EXISTS (SELECT 1 FROM "project" WHERE "id" = $9 AND "name" = $10);\n'

            test.equals m.sql(), expected
            test.deepEqual m.params(), [5, 'Amazing Project', false, 5, 'Amazing Project', 5, 'Amazing Project', false, 5, 'Amazing Project']
            test.done()
