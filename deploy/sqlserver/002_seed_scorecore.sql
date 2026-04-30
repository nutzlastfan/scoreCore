/*
ScoreCore seed data for SQL Server.

Run after 001_create_scorecore_tables.sql.
Edit the SQLCMD variables before execution if needed.
*/

:setvar DatabaseName "Scoring"
:setvar AdminUser "admin"
:setvar AdminEmail "admin@example.local"
:setvar AdminPasswordHash "pbkdf2_sha256$1000000$scorecoreseed$/LOsaQApTwzP9H3DpKYqVoXZe4pvT9SZbDFKJiqG4E4="
:setvar DemoProjectName "Demo"
:setvar DemoImageDir "Demo"

USE [$(DatabaseName)];
GO

SET NOCOUNT ON;
GO

DECLARE @content_types TABLE (
    app_label nvarchar(100) NOT NULL,
    model nvarchar(100) NOT NULL
);

INSERT INTO @content_types (app_label, model)
VALUES
    (N'admin', N'logentry'),
    (N'auth', N'permission'),
    (N'auth', N'group'),
    (N'auth', N'user'),
    (N'contenttypes', N'contenttype'),
    (N'sessions', N'session'),
    (N'authtoken', N'token'),
    (N'token_blacklist', N'outstandingtoken'),
    (N'token_blacklist', N'blacklistedtoken'),
    (N'django_celery_results', N'taskresult'),
    (N'django_celery_results', N'groupresult'),
    (N'django_celery_results', N'chordcounter'),
    (N'scoring', N'backup'),
    (N'scoring', N'project'),
    (N'scoring', N'imagefile'),
    (N'scoring', N'imagescore'),
    (N'scoring', N'scorefeature');

MERGE [dbo].[django_content_type] AS target
USING @content_types AS source
ON target.[app_label] = source.[app_label] AND target.[model] = source.[model]
WHEN NOT MATCHED THEN
    INSERT ([app_label], [model]) VALUES (source.[app_label], source.[model]);
GO

DECLARE @permissions TABLE (
    app_label nvarchar(100) NOT NULL,
    model nvarchar(100) NOT NULL,
    action nvarchar(20) NOT NULL,
    action_name nvarchar(20) NOT NULL
);

INSERT INTO @permissions (app_label, model, action, action_name)
SELECT app_label, model, action, action_name
FROM [dbo].[django_content_type]
CROSS APPLY (VALUES
    (N'add', N'Can add'),
    (N'change', N'Can change'),
    (N'delete', N'Can delete'),
    (N'view', N'Can view')
) AS actions(action, action_name);

MERGE [dbo].[auth_permission] AS target
USING (
    SELECT
        ct.[id] AS content_type_id,
        CONCAT(p.[action], N'_', p.[model]) AS codename,
        CONCAT(p.[action_name], N' ', p.[model]) AS name
    FROM @permissions p
    INNER JOIN [dbo].[django_content_type] ct
        ON ct.[app_label] = p.[app_label] AND ct.[model] = p.[model]
) AS source
ON target.[content_type_id] = source.[content_type_id] AND target.[codename] = source.[codename]
WHEN NOT MATCHED THEN
    INSERT ([name], [content_type_id], [codename])
    VALUES (source.[name], source.[content_type_id], source.[codename]);
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[auth_user] WHERE [username] = N'$(AdminUser)')
BEGIN
    INSERT INTO [dbo].[auth_user] (
        [password],
        [last_login],
        [is_superuser],
        [username],
        [first_name],
        [last_name],
        [email],
        [is_staff],
        [is_active],
        [date_joined]
    )
    VALUES (
        N'$(AdminPasswordHash)',
        NULL,
        1,
        N'$(AdminUser)',
        N'',
        N'',
        N'$(AdminEmail)',
        1,
        1,
        SYSDATETIMEOFFSET()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[auth_user] WHERE [username] = N'scorer1')
BEGIN
    INSERT INTO [dbo].[auth_user] (
        [password],
        [last_login],
        [is_superuser],
        [username],
        [first_name],
        [last_name],
        [email],
        [is_staff],
        [is_active],
        [date_joined]
    )
    VALUES (
        N'$(AdminPasswordHash)',
        NULL,
        0,
        N'scorer1',
        N'Scorer',
        N'One',
        N'scorer1@example.local',
        0,
        1,
        SYSDATETIMEOFFSET()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[scoring_project] WHERE [name] = N'$(DemoProjectName)')
BEGIN
    INSERT INTO [dbo].[scoring_project] (
        [name],
        [icon],
        [image_dir],
        [wanted_scores_per_user],
        [wanted_scores_per_image]
    )
    VALUES (
        N'$(DemoProjectName)',
        N'',
        N'$(DemoImageDir)',
        100,
        2
    );
END
GO

DECLARE @project_id int = (SELECT [id] FROM [dbo].[scoring_project] WHERE [name] = N'$(DemoProjectName)');
DECLARE @admin_id int = (SELECT [id] FROM [dbo].[auth_user] WHERE [username] = N'$(AdminUser)');
DECLARE @scorer_id int = (SELECT [id] FROM [dbo].[auth_user] WHERE [username] = N'scorer1');

IF @project_id IS NOT NULL AND @admin_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM [dbo].[scoring_project_users]
    WHERE [project_id] = @project_id AND [user_id] = @admin_id
)
BEGIN
    INSERT INTO [dbo].[scoring_project_users] ([project_id], [user_id])
    VALUES (@project_id, @admin_id);
END

IF @project_id IS NOT NULL AND @scorer_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM [dbo].[scoring_project_users]
    WHERE [project_id] = @project_id AND [user_id] = @scorer_id
)
BEGIN
    INSERT INTO [dbo].[scoring_project_users] ([project_id], [user_id])
    VALUES (@project_id, @scorer_id);
END

IF @project_id IS NOT NULL
BEGIN
    MERGE [dbo].[scoring_scorefeature] AS target
    USING (VALUES
        (N'Feature 1', 1, 3),
        (N'Feature 2', 2, 3),
        (N'Feature 3', 4, 3)
    ) AS source([name], [bit], [option_count])
    ON target.[project_id] = @project_id AND target.[name] = source.[name]
    WHEN NOT MATCHED THEN
        INSERT ([name], [bit], [option_count], [project_id])
        VALUES (source.[name], source.[bit], source.[option_count], @project_id);
END
GO

PRINT N'ScoreCore seed completed. Initial password for admin and scorer1 is ChangeMe123!';
GO
