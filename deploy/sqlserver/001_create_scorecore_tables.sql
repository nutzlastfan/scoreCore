/*
ScoreCore SQL Server schema.

Run in SQLCMD mode after creating the database:

    :setvar DatabaseName "Scoring"
    :r .\001_create_scorecore_tables.sql

This script creates the Django core tables used by this application plus the
ScoreCore app tables. It is intended for an empty database.
*/

:setvar DatabaseName "Scoring"
USE [$(DatabaseName)];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[django_migrations]', N'U') IS NULL
CREATE TABLE [dbo].[django_migrations] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_django_migrations] PRIMARY KEY,
    [app] nvarchar(255) NOT NULL,
    [name] nvarchar(255) NOT NULL,
    [applied] datetimeoffset NOT NULL
);
GO

IF OBJECT_ID(N'[dbo].[django_content_type]', N'U') IS NULL
CREATE TABLE [dbo].[django_content_type] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_django_content_type] PRIMARY KEY,
    [app_label] nvarchar(100) NOT NULL,
    [model] nvarchar(100) NOT NULL,
    CONSTRAINT [UQ_django_content_type_app_model] UNIQUE ([app_label], [model])
);
GO

IF OBJECT_ID(N'[dbo].[auth_group]', N'U') IS NULL
CREATE TABLE [dbo].[auth_group] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_auth_group] PRIMARY KEY,
    [name] nvarchar(150) NOT NULL CONSTRAINT [UQ_auth_group_name] UNIQUE
);
GO

IF OBJECT_ID(N'[dbo].[auth_permission]', N'U') IS NULL
CREATE TABLE [dbo].[auth_permission] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_auth_permission] PRIMARY KEY,
    [name] nvarchar(255) NOT NULL,
    [content_type_id] int NOT NULL,
    [codename] nvarchar(100) NOT NULL,
    CONSTRAINT [FK_auth_permission_content_type] FOREIGN KEY ([content_type_id]) REFERENCES [dbo].[django_content_type] ([id]),
    CONSTRAINT [UQ_auth_permission_content_codename] UNIQUE ([content_type_id], [codename])
);
GO

IF OBJECT_ID(N'[dbo].[auth_group_permissions]', N'U') IS NULL
CREATE TABLE [dbo].[auth_group_permissions] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_auth_group_permissions] PRIMARY KEY,
    [group_id] int NOT NULL,
    [permission_id] int NOT NULL,
    CONSTRAINT [FK_auth_group_permissions_group] FOREIGN KEY ([group_id]) REFERENCES [dbo].[auth_group] ([id]) ON DELETE CASCADE,
    CONSTRAINT [FK_auth_group_permissions_permission] FOREIGN KEY ([permission_id]) REFERENCES [dbo].[auth_permission] ([id]) ON DELETE CASCADE,
    CONSTRAINT [UQ_auth_group_permissions] UNIQUE ([group_id], [permission_id])
);
GO

IF OBJECT_ID(N'[dbo].[auth_user]', N'U') IS NULL
CREATE TABLE [dbo].[auth_user] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_auth_user] PRIMARY KEY,
    [password] nvarchar(128) NOT NULL,
    [last_login] datetimeoffset NULL,
    [is_superuser] bit NOT NULL CONSTRAINT [DF_auth_user_is_superuser] DEFAULT (0),
    [username] nvarchar(150) NOT NULL CONSTRAINT [UQ_auth_user_username] UNIQUE,
    [first_name] nvarchar(150) NOT NULL CONSTRAINT [DF_auth_user_first_name] DEFAULT (N''),
    [last_name] nvarchar(150) NOT NULL CONSTRAINT [DF_auth_user_last_name] DEFAULT (N''),
    [email] nvarchar(254) NOT NULL CONSTRAINT [DF_auth_user_email] DEFAULT (N''),
    [is_staff] bit NOT NULL CONSTRAINT [DF_auth_user_is_staff] DEFAULT (0),
    [is_active] bit NOT NULL CONSTRAINT [DF_auth_user_is_active] DEFAULT (1),
    [date_joined] datetimeoffset NOT NULL CONSTRAINT [DF_auth_user_date_joined] DEFAULT (SYSDATETIMEOFFSET())
);
GO

IF OBJECT_ID(N'[dbo].[auth_user_groups]', N'U') IS NULL
CREATE TABLE [dbo].[auth_user_groups] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_auth_user_groups] PRIMARY KEY,
    [user_id] int NOT NULL,
    [group_id] int NOT NULL,
    CONSTRAINT [FK_auth_user_groups_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id]) ON DELETE CASCADE,
    CONSTRAINT [FK_auth_user_groups_group] FOREIGN KEY ([group_id]) REFERENCES [dbo].[auth_group] ([id]) ON DELETE CASCADE,
    CONSTRAINT [UQ_auth_user_groups] UNIQUE ([user_id], [group_id])
);
GO

IF OBJECT_ID(N'[dbo].[auth_user_user_permissions]', N'U') IS NULL
CREATE TABLE [dbo].[auth_user_user_permissions] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_auth_user_user_permissions] PRIMARY KEY,
    [user_id] int NOT NULL,
    [permission_id] int NOT NULL,
    CONSTRAINT [FK_auth_user_permissions_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id]) ON DELETE CASCADE,
    CONSTRAINT [FK_auth_user_permissions_permission] FOREIGN KEY ([permission_id]) REFERENCES [dbo].[auth_permission] ([id]) ON DELETE CASCADE,
    CONSTRAINT [UQ_auth_user_user_permissions] UNIQUE ([user_id], [permission_id])
);
GO

IF OBJECT_ID(N'[dbo].[django_admin_log]', N'U') IS NULL
CREATE TABLE [dbo].[django_admin_log] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_django_admin_log] PRIMARY KEY,
    [action_time] datetimeoffset NOT NULL,
    [object_id] nvarchar(max) NULL,
    [object_repr] nvarchar(200) NOT NULL,
    [action_flag] smallint NOT NULL,
    [change_message] nvarchar(max) NOT NULL,
    [content_type_id] int NULL,
    [user_id] int NOT NULL,
    CONSTRAINT [CK_django_admin_log_action_flag] CHECK ([action_flag] >= 0),
    CONSTRAINT [FK_django_admin_log_content_type] FOREIGN KEY ([content_type_id]) REFERENCES [dbo].[django_content_type] ([id]),
    CONSTRAINT [FK_django_admin_log_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id])
);
GO

IF OBJECT_ID(N'[dbo].[django_session]', N'U') IS NULL
CREATE TABLE [dbo].[django_session] (
    [session_key] nvarchar(40) NOT NULL CONSTRAINT [PK_django_session] PRIMARY KEY,
    [session_data] nvarchar(max) NOT NULL,
    [expire_date] datetimeoffset NOT NULL
);
CREATE INDEX [IX_django_session_expire_date] ON [dbo].[django_session] ([expire_date]);
GO

IF OBJECT_ID(N'[dbo].[authtoken_token]', N'U') IS NULL
CREATE TABLE [dbo].[authtoken_token] (
    [key] nvarchar(40) NOT NULL CONSTRAINT [PK_authtoken_token] PRIMARY KEY,
    [created] datetimeoffset NOT NULL,
    [user_id] int NOT NULL CONSTRAINT [UQ_authtoken_token_user] UNIQUE,
    CONSTRAINT [FK_authtoken_token_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id]) ON DELETE CASCADE
);
GO

IF OBJECT_ID(N'[dbo].[token_blacklist_outstandingtoken]', N'U') IS NULL
CREATE TABLE [dbo].[token_blacklist_outstandingtoken] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_token_blacklist_outstandingtoken] PRIMARY KEY,
    [user_id] int NULL,
    [jti] nvarchar(255) NOT NULL CONSTRAINT [UQ_token_blacklist_outstandingtoken_jti] UNIQUE,
    [token] nvarchar(max) NOT NULL,
    [created_at] datetimeoffset NULL,
    [expires_at] datetimeoffset NOT NULL,
    CONSTRAINT [FK_token_blacklist_outstandingtoken_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id]) ON DELETE CASCADE
);
GO

IF OBJECT_ID(N'[dbo].[token_blacklist_blacklistedtoken]', N'U') IS NULL
CREATE TABLE [dbo].[token_blacklist_blacklistedtoken] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_token_blacklist_blacklistedtoken] PRIMARY KEY,
    [blacklisted_at] datetimeoffset NOT NULL,
    [token_id] int NOT NULL CONSTRAINT [UQ_token_blacklist_blacklistedtoken_token] UNIQUE,
    CONSTRAINT [FK_token_blacklist_blacklistedtoken_token] FOREIGN KEY ([token_id]) REFERENCES [dbo].[token_blacklist_outstandingtoken] ([id]) ON DELETE CASCADE
);
GO

IF OBJECT_ID(N'[dbo].[django_celery_results_taskresult]', N'U') IS NULL
CREATE TABLE [dbo].[django_celery_results_taskresult] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_django_celery_results_taskresult] PRIMARY KEY,
    [task_id] nvarchar(255) NOT NULL CONSTRAINT [UQ_django_celery_results_task_id] UNIQUE,
    [status] nvarchar(50) NOT NULL,
    [content_type] nvarchar(128) NOT NULL,
    [content_encoding] nvarchar(64) NOT NULL,
    [result] nvarchar(max) NULL,
    [date_done] datetimeoffset NOT NULL,
    [traceback] nvarchar(max) NULL,
    [meta] nvarchar(max) NULL,
    [task_args] nvarchar(max) NULL,
    [task_kwargs] nvarchar(max) NULL,
    [task_name] nvarchar(255) NULL,
    [worker] nvarchar(100) NULL,
    [date_created] datetimeoffset NOT NULL
);
CREATE INDEX [IX_django_celery_results_taskresult_status] ON [dbo].[django_celery_results_taskresult] ([status]);
CREATE INDEX [IX_django_celery_results_taskresult_date_done] ON [dbo].[django_celery_results_taskresult] ([date_done]);
GO

IF OBJECT_ID(N'[dbo].[django_celery_results_groupresult]', N'U') IS NULL
CREATE TABLE [dbo].[django_celery_results_groupresult] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_django_celery_results_groupresult] PRIMARY KEY,
    [group_id] nvarchar(255) NOT NULL CONSTRAINT [UQ_django_celery_results_group_id] UNIQUE,
    [date_created] datetimeoffset NOT NULL,
    [date_done] datetimeoffset NOT NULL,
    [content_type] nvarchar(128) NOT NULL,
    [content_encoding] nvarchar(64) NOT NULL,
    [result] nvarchar(max) NULL
);
GO

IF OBJECT_ID(N'[dbo].[django_celery_results_chordcounter]', N'U') IS NULL
CREATE TABLE [dbo].[django_celery_results_chordcounter] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_django_celery_results_chordcounter] PRIMARY KEY,
    [group_id] nvarchar(255) NOT NULL CONSTRAINT [UQ_django_celery_results_chordcounter_group_id] UNIQUE,
    [sub_tasks] nvarchar(max) NOT NULL,
    [count] int NOT NULL
);
GO

IF OBJECT_ID(N'[dbo].[scoring_backup]', N'U') IS NULL
CREATE TABLE [dbo].[scoring_backup] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_scoring_backup] PRIMARY KEY,
    [name] nvarchar(100) NOT NULL,
    [date] datetimeoffset NULL
);
GO

IF OBJECT_ID(N'[dbo].[scoring_project]', N'U') IS NULL
CREATE TABLE [dbo].[scoring_project] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_scoring_project] PRIMARY KEY,
    [name] nvarchar(100) NOT NULL CONSTRAINT [UQ_scoring_project_name] UNIQUE,
    [icon] nvarchar(5) NULL CONSTRAINT [DF_scoring_project_icon] DEFAULT (N''),
    [image_dir] nvarchar(500) NULL,
    [wanted_scores_per_user] int NULL CONSTRAINT [DF_scoring_project_scores_per_user] DEFAULT (100),
    [wanted_scores_per_image] int NULL CONSTRAINT [DF_scoring_project_scores_per_image] DEFAULT (2)
);
GO

IF OBJECT_ID(N'[dbo].[scoring_project_users]', N'U') IS NULL
CREATE TABLE [dbo].[scoring_project_users] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_scoring_project_users] PRIMARY KEY,
    [project_id] int NOT NULL,
    [user_id] int NOT NULL,
    CONSTRAINT [FK_scoring_project_users_project] FOREIGN KEY ([project_id]) REFERENCES [dbo].[scoring_project] ([id]) ON DELETE CASCADE,
    CONSTRAINT [FK_scoring_project_users_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id]) ON DELETE CASCADE,
    CONSTRAINT [UQ_scoring_project_users] UNIQUE ([project_id], [user_id])
);
GO

IF OBJECT_ID(N'[dbo].[scoring_imagefile]', N'U') IS NULL
CREATE TABLE [dbo].[scoring_imagefile] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_scoring_imagefile] PRIMARY KEY,
    [filename] nvarchar(50) NOT NULL,
    [path] nvarchar(500) NOT NULL,
    [useless] bit NOT NULL CONSTRAINT [DF_scoring_imagefile_useless] DEFAULT (0),
    [hidden] bit NOT NULL CONSTRAINT [DF_scoring_imagefile_hidden] DEFAULT (0),
    [stddev] float NULL CONSTRAINT [DF_scoring_imagefile_stddev] DEFAULT (0),
    [data] nvarchar(max) NOT NULL CONSTRAINT [DF_scoring_imagefile_data] DEFAULT (N'{}'),
    [width] int NOT NULL CONSTRAINT [DF_scoring_imagefile_width] DEFAULT (0),
    [height] int NOT NULL CONSTRAINT [DF_scoring_imagefile_height] DEFAULT (0),
    [frame_x] int NOT NULL CONSTRAINT [DF_scoring_imagefile_frame_x] DEFAULT (0),
    [frame_y] int NOT NULL CONSTRAINT [DF_scoring_imagefile_frame_y] DEFAULT (0),
    [frame_w] int NOT NULL CONSTRAINT [DF_scoring_imagefile_frame_w] DEFAULT (0),
    [frame_h] int NOT NULL CONSTRAINT [DF_scoring_imagefile_frame_h] DEFAULT (0),
    [date] datetimeoffset NULL,
    [raw_hash] nvarchar(32) NULL,
    [project_id] int NOT NULL,
    CONSTRAINT [FK_scoring_imagefile_project] FOREIGN KEY ([project_id]) REFERENCES [dbo].[scoring_project] ([id]) ON DELETE CASCADE,
    CONSTRAINT [CK_scoring_imagefile_data_json] CHECK (ISJSON([data]) = 1)
);
CREATE INDEX [IX_scoring_imagefile_project] ON [dbo].[scoring_imagefile] ([project_id]);
GO

IF OBJECT_ID(N'[dbo].[scoring_scorefeature]', N'U') IS NULL
CREATE TABLE [dbo].[scoring_scorefeature] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_scoring_scorefeature] PRIMARY KEY,
    [name] nvarchar(255) NOT NULL,
    [bit] int NOT NULL CONSTRAINT [DF_scoring_scorefeature_bit] DEFAULT (0),
    [option_count] int NOT NULL CONSTRAINT [DF_scoring_scorefeature_option_count] DEFAULT (3),
    [project_id] int NOT NULL,
    CONSTRAINT [FK_scoring_scorefeature_project] FOREIGN KEY ([project_id]) REFERENCES [dbo].[scoring_project] ([id]) ON DELETE CASCADE
);
CREATE INDEX [IX_scoring_scorefeature_project] ON [dbo].[scoring_scorefeature] ([project_id]);
GO

IF OBJECT_ID(N'[dbo].[scoring_imagescore]', N'U') IS NULL
CREATE TABLE [dbo].[scoring_imagescore] (
    [id] int IDENTITY(1,1) NOT NULL CONSTRAINT [PK_scoring_imagescore] PRIMARY KEY,
    [date] datetimeoffset NULL,
    [comment] nvarchar(255) NULL CONSTRAINT [DF_scoring_imagescore_comment] DEFAULT (N''),
    [data] nvarchar(max) NOT NULL CONSTRAINT [DF_scoring_imagescore_data] DEFAULT (N'{}'),
    [is_completed] bit NOT NULL CONSTRAINT [DF_scoring_imagescore_is_completed] DEFAULT (0),
    [file_id] int NOT NULL,
    [user_id] int NOT NULL,
    [project_id] int NOT NULL,
    CONSTRAINT [FK_scoring_imagescore_file] FOREIGN KEY ([file_id]) REFERENCES [dbo].[scoring_imagefile] ([id]) ON DELETE CASCADE,
    CONSTRAINT [FK_scoring_imagescore_user] FOREIGN KEY ([user_id]) REFERENCES [dbo].[auth_user] ([id]) ON DELETE CASCADE,
    -- SQL Server rejects the second cascade path Project -> ImageScore because
    -- Project already cascades through ImageFile -> ImageScore. Keep this FK
    -- restrictive and let file_id handle score cleanup for project deletes.
    CONSTRAINT [FK_scoring_imagescore_project] FOREIGN KEY ([project_id]) REFERENCES [dbo].[scoring_project] ([id]) ON DELETE NO ACTION,
    CONSTRAINT [CK_scoring_imagescore_data_json] CHECK (ISJSON([data]) = 1)
);
CREATE INDEX [IX_scoring_imagescore_file] ON [dbo].[scoring_imagescore] ([file_id]);
CREATE INDEX [IX_scoring_imagescore_user] ON [dbo].[scoring_imagescore] ([user_id]);
CREATE INDEX [IX_scoring_imagescore_project] ON [dbo].[scoring_imagescore] ([project_id]);
GO
