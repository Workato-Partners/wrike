# frozen_string_literal: true

descriptor = {
  title: "Wrike",

  connection: {
    fields: [
      {
        name: "client_id",
        control_type: "text",
        label: "Client ID",
        optional: false,
        hint: "Your client id"
      },
      {
        name: "client_secret",
        control_type: "password",
        label: "Client secret",
        optional: false,
        hint: "Your client secret"
      },
      {
        name: "advanced_settings",
        optional: true,
        type: "object",
        properties: [
          {
            name: "api_scope", control_type: "multiselect",
            delimiter: ",",
            optional: true,
            options: [
              ["WSREADONLY", "wsReadOnly"],
              ["WSREADWRITE", "wsReadWrite"],
              ["AMREADONLYWORKFLOW", "amReadOnlyWorkflow"],
              ["AMREADWRITEWORKFLOW", "amReadWriteWorkflow"],
              ["AMREADONLYINVITATION", "amReadOnlyInvitation"],
              ["AMREADWRITEINVITATION", "amReadWriteInvitation"],
              ["AMREADONLYGROUP", "amReadOnlyGroup"],
              ["AMREADWRITEGROUP", "amReadWriteGroup"],
              ["AMREADONLYUSER", "amReadOnlyUser"],
              ["AMREADWRITEUSER", "amReadWriteUser"],
              ["AMREADONLYAUDITLOG", "amReadOnlyAuditLog"]
            ],
            hint: 'Select <a href="https://developers.wrike.com/documentation/api/overview" target="_blank">permissions</a>' \
            "to request for this connection. Defaults to <b>Default</b> if left blank." \
            "<br/>Minimum permissions required is <b>Default</b>, which will be always requested in addition to selected permissions." \
          }
        ]
      }
    ],

    authorization: {
      type: "oauth2",
      refresh_on: 401,

      authorization_url: ->(settings) {
        scope = if settings.dig("advanced_settings", "api_scope").present?
                  "&scope=#{settings.dig('advanced_settings', 'api_scope')},Default"
                else
                  "&scope=Default"
                end
        "https://login.wrike.com/oauth2/authorize/v4?client_id=#{settings['client_id']}&response_type=code#{scope}"
      },

      token_url: -> {
        "https://login.wrike.com/oauth2/token"
      },

      credentials: ->(_, access_token) {
        headers(Authorization: "Bearer #{access_token}")
      },

      acquire: ->(input, auth_code, redirect_url) {
        output = post("https://login.wrike.com/oauth2/token")
                   .payload(
                     client_id: input["client_id"],
                     client_secret: input["client_secret"],
                     grant_type: :authorization_code,
                     redirect_uri: redirect_url,
                     code: auth_code
                   )
                   .request_format_www_form_urlencoded

        [
          output,
          nil,
          { host: output["host"] }
        ]
      },

      refresh: ->(settings, refresh_token) {
        scope = if settings.dig("advanced_settings", "api_scope").present?
                  "&scope=#{settings.dig('advanced_settings', 'api_scope')},Default"
                else
                  "&scope=Default"
                end
        post("https://login.wrike.com/oauth2/token")
          .payload({
            client_id: settings["client_id"],
            client_secret: settings["client_secret"],
            grant_type: :refresh_token,
            refresh_token: refresh_token,
            scope: scope
          }.compact)
          .request_format_www_form_urlencoded
      },

      identity: ->(connection) {
        get(call(:base_uri, connection) + "/contacts").params(me: true).dig("data", 0, "profiles", 0, "email")
      }
    }
  },

  test: ->(connection) {
    get(call(:base_uri, connection) + "/contacts?me=true")
  },

  object_definitions: {

    task: {
      fields: -> {
        [
          { name: "id", label: "Task ID", hint: "ID of task." },
          { name: "accountId" },
          { name: "folder_id", optional: false, hint: "ID of folder where task will be created." },
          { name: "title",
            hint: "Title of task.",
            sticky: true },
          { name: "description", hint: "Description of task." },
          { name: "briefDescription" },
          { name: "parentIds", label: "Parent folder", type: :array, properties: [
            { name: "parentIds", label: "Parent folder ID", hint: "Parent folders for task. Cannot contain Recyclebin ID." }
          ] },
          { name: "superParentIds", label: "Superparent folder", type: :array, properties: [
            { name: "superParentIds", label: "Folder ID", hint: "Super parent folder for task." }
          ] },
          { name: "sharedIds", label: "List of users who share task", type: :array, properties: [
            { name: "sharedIds", label: "User ID", hint: "User IDs who share task." }
          ] },
          { name: "responsibleIds", label: "Assignees", type: :array, properties: [
            { name: "responsibleIds", label: "User ID", hint: "User ID of assignees." }
          ] },
          { name: "status",
            hint: "Allowed values are <b>Active</b>, <b>Completed</b>, <b>Deferred</b> and <b>Cancelled</b>.",
            sticky: true },
          { name: "importance",
            hint: "Allowed values are <b>High</b>, <b>Normal</b> and <b>Low</b>." },
          { name: "createdDate", type: :date_time, hint: "Retrieve tasks created after this date and time." },
          { name: "updatedDate", type: :date_time, hint: "Retrieve tasks updated after this date and time." },
          { name: "completedDate", type: :date_time, hint: "Retrieve tasks completed after this date and time." },
          { name: "dates", type: :object, properties: [
            { name: "type",
              hint: "Allowed values are <b>Backlog</b>, <b>Milestone</b> and <b>Planned</b>.",
              sticky: true },
            { name: "duration", type: :integer, hint: "In minutes." },
            { name: "start", type: :date_time, hint: "Should be present only in planned tasks." },
            { name: "due", type: :date_time, hint: "Should be present only in planned/milestone tasks." },
            { name: "workOnWeekends", type: :boolean }
          ] },
          { name: "scope" },
          { name: "authorIds", label: "Author", type: :array, properties: [
            { name: "authorIds", label: "User ID", hint: "List of author user IDs." }
          ] },
          { name: "customStatusId", label: "Custom Status ID" },
          { name: "custom_status", type: :object, properties: [
            { name: "name" },
            { name: "id" }
          ] },
          { name: "hasAttachments", type: :boolean },
          { name: "attachmentCount", type: :integer },
          { name: "permalink", hint: "Can be found in task page. Get permalink by hovering over permalink icon." },
          { name: "priority" },
          { name: "followedByMe", type: :boolean },
          { name: "followerIds", label: "Followers", type: :array, properties: [
            { name: "followerIds", label: "Follower ID", hint: "User IDs who follow task." }
          ] },
          { name: "overrideRights" },
          { name: "recurrent", type: :boolean },
          { name: "superTaskIds", label: "Super task", type: :array, properties: [
            { name: "superTaskIds", label: "Super task ID", hint: "IDs of super tasks." }
          ] },
          { name: "subTaskIds", label: "Subtask", type: :array, properties: [
            { name: "subTaskIds", label: "Subtask ID", hint: "IDs of sub tasks." }
          ] },
          { name: "dependencyIds", label: "Dependency", type: :array, properties: [
            { name: "dependencyIds", label: "Dependency ID", hint: "IDs of dependent tasks." }
          ] },
          { name: "metadata", hint: "Retrieve folders with this metadata.", type: :array, of: :object, properties: [
            { name: "key", hint: "Key can be of alphanumeric values with maximum length up to 50 characters." },
            { name: "value", hint: "Metadata field value." }
          ] },
          { name: "timeLogHours", type: :integer },
          { name: "responsibles", label: "Assignee", type: :array, properties: [
            { name: "id", label: "Assignee ID", hint: "User ID of assignee." }
          ] },
          { name: "priorityAfter",
            hint: "Use if <b>Priority before</b> field is not provided. Enter task ID after which task should be created." },
          { name: "priorityBefore",
            hint: "Use if <b>Priority after</b> field is not provided. Enter task ID before which task should be created." },
          { name: "follow",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to follow task. Defaults to <b>false</b>." },
          { name: "addShareds", label: "Share task with users", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Share task with specified users." }
          ] },
          { name: "removeShareds", label: "Unshare task from users", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Unshare task from specified users." }
          ] },
          { name: "removeParents", label: "Remove parent folders", type: :array, properties: [
            { name: "id", label: "Parent folder ID", hint: "Remove task from parent folder. Cannot contain RecycleBin folder ID." }
          ] },
          { name: "addParents", label: "Add parent folders", type: :array, properties: [
            { name: "id", label: "Folder ID", hint: "Add task to parent folder ID. Cannot contain RecycleBin folder ID." }
          ] },
          { name: "addResponsibles", label: "Add assignees", type: :array, properties: [
            { name: "id", label: "Assignee ID", hint: "Add specified user as assignee." }
          ] },
          { name: "removeResponsibles", label: "Remove assignees", type: :array, properties: [
            { name: "id", label: "Assignee ID", hint: "Remove specified user as assignee." }
          ] },
          { name: "addSuperTasks", label: "Add super tasks", type: :array, properties: [
            { name: "id", label: "Task ID", hint: "Add task as subtask to specified task." }
          ] },
          { name: "removeSuperTasks", label: "Remove super tasks", type: :array, properties: [
            { name: "id", label: "Task ID", hint: "Remove task from specified super task." }
          ] },
          { name: "shareds", label: "Share task with users", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Task is shared with author by default." }
          ] },
          { name: "parents", label: "Add parent folders", type: :array, properties: [
            { name: "id", label: "Parent folder ID", hint: "Cannot contain recycle bin ID." }
          ] },
          { name: "followers", type: :array, properties: [
            { name: "id", hint: "User ID of follower.", label: "User ID" }
          ] },
          { name: "superTasks", type: :array, properties: [
            { name: "id", label: "Task ID", hint: "Add task as subtask to specified task ID." }
          ] },
          { name: "restore",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to restore task from recycle bin. Defaults to <b>false</b>." }
        ]
      }
    },

    custom: {
      fields: ->(connection, config_fields) {
        custom = get(call(:base_uri, connection) + "/customfields")&.[]("data")
        field_list = config_fields["field_list"]&.split("\n")&.map { |f| f.split("___")[1] }
        custom = custom.select { |out| field_list.include? out["id"] } if field_list.present?
        if custom.present?
          [
            {
              name: "customFields", custom: true, sticky: true, type: :object, properties:
              custom.sort_by { |field| field["title"].downcase }.map do |field|
                attributes = { name: field["id"], label: field["title"], sticky: true, custom: true }
                case field["type"]
                when "Checkbox"
                  { type: :boolean, name: field["id"], label: field["title"], sticky: true, custom: true }
                when "Numeric"
                  { control_type: :number, hint: "Example: 32000", name: field["id"], label: field["title"], sticky: true, custom: true }
                when "Percentage"
                  { type: :string, hint: "Example: 75", name: field["id"], label: field["title"], sticky: true, custom: true }
                when "Currency"
                  { type: :string, hint: "Example: 1000", name: field["id"], label: field["title"], sticky: true, custom: true }
                when "Duration"
                  { type: :string, hint: "Expected format <b>h m s</b>, Example: 37h 12m 22s", name: field["id"], label: field["title"], sticky: true, custom: true }
                when "Date"
                  { type: :date, name: field["id"], label: field["title"], sticky: true, custom: true }
                when "Contacts"
                  { type: :string, hint: "Enter #{field['title'].labelize} user ID", name: field["id"], label: field["title"], sticky: true, custom: true }
                else
                  attributes
                end
              end
            }
          ]
        end || []
      }
    },

    custom_field: {
      fields: ->(_, config) {
        if config["custom_field_list"].present?
          meta = config["custom_field_list"].split("___")
          attributes = { name: meta[1], label: meta[0], sticky: true, custom: true }
          [
            { name: "customField", custom: true, type: :object, render_input: :search_custom_field, properties: [
              case meta[2]
              when "Checkbox"
                { type: :boolean, name: meta[1], label: meta[0], sticky: true, custom: true }
              when "Numeric"
                { control_type: :number, hint: "Example: 32000", name: meta[1], label: meta[0], sticky: true, custom: true }
              when "Percentage"
                { type: :string, hint: "Example: 75", name: meta[1], label: meta[0], sticky: true, custom: true }
              when "Currency"
                { type: :string, hint: "Example: 1000", name: meta[1], label: meta[0], sticky: true, custom: true }
              when "Duration"
                { type: :string, hint: "Expected format <b>h m s</b>, Example: 37h 12m 22s", name: meta[1], label: meta[0], sticky: true, custom: true }
              when "Date"
                { type: :date, name: meta[1], label: meta[0], sticky: true, custom: true }
              when "Contacts"
                { type: :string, hint: "Enter #{meta[0].labelize} user ID", name: meta[1], label: meta[0], sticky: true, custom: true }
              else
                attributes
              end
            ] }
          ]
        end || []
      }
    },

    comment: {
      fields: -> {
        [
          { name: "plainText", type: :boolean, hint: "Treats comment as plain text for 'false' and as HTML for 'true'." },
          { name: "id", label: "Comment ID", hint: "ID of comment." },
          { name: "authorId", label: "Author ID", hint: "Comment author's user ID." },
          { name: "text", optional: false },
          { name: "updatedDate", type: :date_time, hint: "Date when comment was updated." },
          { name: "createdDate", type: :date_time, hint: "Date when comment was created." },
          { name: "folderId", label: "Folder ID", hint: "ID of folder.", sticky: true },
          { name: "taskId", label: "Task ID", hint: "ID of task.", sticky: true }
        ]
      }
    },

    contact: {
      fields: -> {
        [
          { name: "id" },
          { name: "firstName" },
          { name: "lastName" },
          { name: "type" },
          { name: "title" },
          { name: "phone" },
          { name: "profiles", type: :array, of: :object, properties: [
            { name: "accountId", label: "Account ID" },
            { name: "email" },
            { name: "role" },
            { name: "external", type: :boolean },
            { name: "admin", type: :boolean },
            { name: "owner", type: :boolean }
          ] },
          { name: "avatarUrl" },
          { name: "timezone" },
          { name: "locale" },
          { name: "deleted", type: :boolean },
          { name: "memberIds", label: "Member ID" },
          { name: "myTeam", type: :boolean }
        ]
      }
    },

    folder: {
      fields: -> {
        [
          { name: "id", label: "Folder ID", hint: "ID of folder." },
          { name: "accountId" },
          { name: "title", hint: "Title of folder." },
          { name: "createdDate", type: :date_time, hint: "Retrieve folders/projects created after this date and time." },
          { name: "updatedDate", type: :date_time, sticky: true, hint: "Retrieve folders/projects updated after this date and time." },
          { name: "briefDescription" },
          { name: "description", hint: "Description of folder.", sticky: true },
          { name: "folder_id", hint: "ID of parent folder.", optional: false },
          { name: "shareds", label: "Users who share the folder", type: :array, properties: [
            { name: "id", label: "User ID", hint: "User ID of user to share folder with." }
          ] },
          { name: "sharedIds", label: "Users who share the folder", type: :array, properties: [
            { name: "sharedIds", label: "User ID", hint: "User ID of user to share folder with." }
          ] },
          { name: "parentIds", label: "Parent folder", type: :array, properties: [
            { name: "parentIds", label: "Folder ID" }
          ] },
          { name: "childIds", label: "Child folder", type: :array, properties: [
            { name: "childIds", label: "Folder ID" }
          ] },
          { name: "superParentIds", label: "Super parent folder", type: :array, properties: [{ name: "superParentIds", label: "Folder ID" }] },
          { name: "scope",
            hint: "Allowed values are <b>WsRoot</b>, <b>RbRoot</b>, <b>WsFolder</b>, <b>RbFolder</b>, " \
            "<b>WsTask</b>, and <b>RbTask</b>." },
          { name: "hasAttachments", type: :boolean },
          { name: "attachmentCount", type: :integer },
          { name: "permalink",
            hint: "Retrieves folders matching this permalink. " \
            "Can be found in folder page, get permalink by hovering over permalink icon." },
          { name: "workflowId", label: "Workflow ID" },
          { name: "metadata", type: :array, of: :object, properties: [
            { name: "key", hint: "Key should be less than 50 symbols and match the following regular expression ([A-Za-z0-9_-]+)." },
            { name: "value", hint: "Metadata field value." }
          ] },
          { name: "customColumnIds", label: "Custom field IDs", type: :array, properties: [{ name: "customColumnIds", label: "Custom field ID" }] },
          { name: "custom_status", type: :object, properties: [
            { name: "name" },
            { name: "id" }
          ] },
          { name: "project", sticky: true, type: :object, properties: [
            { name: "authorId", label: "Author", hint: "Project author's user ID." },
            { name: "ownerIds", label: "Owner ID", type: :array, properties: [
              { name: "ownerIds", label: "User ID", hint: "User ID of project owner." }
            ] },
            { name: "status",
              hint: "Allowed values are <b>Green</b>, <b>Yellow</b>, <b>Red</b>, <b>Completed</b>, <b>OnHold</b>, " \
              "and <b>Cancelled</b>." },
            { name: "customStatusId" },
            { name: "startDate", sticky: true, type: :date_time, hint: "Date when project started." },
            { name: "endDate", sticky: true, type: :date_time, hint: "Date when project ended." },
            { name: "createdDate", sticky: true, type: :date_time, hint: "Date when project was created." },
            { name: "completedDate", type: :date_time, hint: "Date when project was completed." }
          ] },
          { name: "parent", label: "Parent folder ID" },
          { name: "copyDescriptions",
            type: :boolean,
            hint: "Enter <b>true</b> to copy folder descriptions into copied parent folders. Defaults to <b>false</b>." },
          { name: "copyResponsibles",
            type: :boolean,
            hint: "Enter <b>true</b> to copy assignees into copied tasks. Defaults to <b>false</b>." },
          { name: "addResponsibles", label: "Add assignees to copied tasks.", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Add assignee to copied tasks." }
          ] },
          { name: "removeResponsibles", label: "Remove assignees from copied tasks", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Remove assignee from copied task." }
          ] },
          { name: "copyCustomFields",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to copy custom fields. Defaults to <bold>false</bold>." },
          { name: "copyCustomStatuses",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to copy custom statuses. Defaults to <b>false</b>." },
          { name: "copyStatuses",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to copy statuses. Defaults to <b>false</b>." },
          { name: "copyParents",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to copy parent folders/projects. Defaults to <b>false</b>." },
          { name: "rescheduleDate", type: :date, render_input: :date_input, hint: "Copy rescheduling dates to copied tasks." },
          { name: "rescheduleMode",
            hint: "Valid only if reschedule date is present. Allowed values are <b>Start</b> and <b>End</b>." },
          { name: "entryLimit", type: :integer, hint: "Limit maximum allowed number for tasks/folders/projects in tree for copy. Valid range: 1-100. 100 by default." },
          { name: "addShareds", label: "Users to share the folder with", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Share folder with specified user ID." }
          ] },
          { name: "removeShareds", label: "Remove users from sharing", type: :array, properties: [
            { name: "id", label: "User ID", hint: "Unshare folder from specified user." }
          ] },
          { name: "removeParents", label: "Remove parent folder", type: :array, properties: [
            { name: "id", label: "Folder ID", hint: "Parent folder ID from same account to remove. Cannot contain rootfolder ID and recyclebin ID." }
          ] },
          { name: "addParents", label: "Add parent folder", type: :array, properties: [
            { name: "id", label: "Folder ID", hint: "Parent folder ID from same account to add. Cannot contain rootfolder ID and recyclebin ID." }
          ] },
          { name: "restore",
            type: :boolean,
            hint: "Enter <b>true</b> using formula mode to restore folder from recycle bin. Defaults to <b>false</b>." }
        ]
      }
    },

    timelog: {
      fields: -> {
        [
          { name: "id", label: "Timelog ID" },
          { name: "taskId", label: "Task ID" },
          { name: "userId", label: "User ID" },
          { name: "categoryId", label: "Category ID" },
          { name: "hours", type: :number },
          { name: "createdDate", type: :date_time },
          { name: "updatedDate", type: :date_time },
          { name: "trackedDate", type: :date },
          { name: "comment" }
        ]
      }
    }
  },

  methods: {
    base_uri: lambda do |input|
      host = input["host"].presence || "www.wrike.com"
      "https://#{host}/api/v4"
    end,

    get_custom_statuses: ->(connection, force_fetch) {
      custom_statuses = nil
      if custom_statuses.nil? || force_fetch
        workflows = get(call(:base_uri, connection) + "/workflows")&.[]("data")
        statuses = {}.tap do |h|
          workflows.each do |wf|
            wf["customStatuses"].each do |cs|
              h[cs["id"]] = { name: cs["name"], wf_name: wf["name"] } if wf["hidden"].is_not_true? && cs["hidden"].is_not_true?
            end
          end
        end
        statuses
      end
    },

    get_updated_custom_statuses: ->(connection, input_custom_status_name, custom_statuses) {
      wf_name = input_custom_status_name.split("|")[0]
      name = input_custom_status_name.split("|")[1]
      custom_status = custom_statuses.find { |_, v| v["name"] == name && v["wf_name"] == wf_name }&.first
      if custom_status.blank?
        custom_statuses = call(:get_custom_statuses, connection, true)
        custom_status = custom_statuses.find { |_, v| v["name"] == name && v["wf_name"] == wf_name }&.first
      end
      custom_status
    },

    format_response: ->(data, connection) {
      if data["customStatusId"].present?
        custom_statuses = call(:get_custom_statuses, connection, false)
        cs = custom_statuses[data["customStatusId"]]
        if cs.blank?
          custom_statuses = call(:get_custom_statuses, connection, true)
          cs = custom_statuses[data["customStatusId"]]
        end
        data["custom_status"] = { name: [cs&.[]("wf_name"), cs&.[]("name")]&.join("|") == "|" ? nil : [cs&.[]("wf_name"), cs&.[]("name")]&.join("|"), id: data["customStatusId"] }
      end

      call(:format_output, data, %w[parentIds superParentIds sharedIds responsibleIds authorIds followerIds superTaskIds subTaskIds dependencyIds])
      call(:format_custom_output, data)
    },

    format_input: ->(input, keys) {
      keys.each do |key|
        input[key] = input[key].map { |v| v&.[]("id") } if input.keys.include?(key)
      end
    },

    format_output: ->(res, keys) {
      res&.each do |k, v|
        res[k] = v.map { |value| { k => value } } if keys.include?(k)
      end
    },

    format_custom_output: ->(response) {
      if response["customFields"].present?
        response["customFields"] = response["customFields"].each_with_object({}) do |cust, h|
          h[cust["id"]] = cust["value"]
        end
      end
      response
    },

    payload_input: ->(input) {
      input.each do |key, val|
        if val.is_a?(Array)
          input[key] = val.to_json
        end
      end
    },

    strip_html_tags: ->(response, strip_tags, default) {
      next if response["description"].blank? || (default.is_not_true? && strip_tags.nil?) || strip_tags == false

      response["description"] = response["description"].strip_tags
    }

    # get_folder_tree: ->(children, data) {
    #   children&.map do |child|
    #     folder = {}
    #     data.delete_if { |f| f['id'] == child && folder = f }
    #     [folder['title'], folder['id'], folder['id'], call(:get_folder_tree, folder['childIds'], data)]
    #   end
    # },

    # get_project_tree: ->(input) {
    #   Array.wrap(get(call("base_uri", input) + "/folders/#{input[:parent_id]}/folders?descendants=false&project=true")&.[]('data')).map do |f|
    #     [f['title'], f['id'], f['id'], true]
    #   end
    # }
  },

  actions: {
    get_task_by_id: {
      description: 'Get <span class="provider">task</span> by ID in <span class="provider">Wrike</span>',
      help: "Retrieves task info and metadata by specifying task ID. Also shows custom fields.",

      config_fields: [
        { name: "id", label: "Task ID", hint: "ID of task to retrieve.", optional: false },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: true,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      input_fields: -> {},

      execute: ->(connection, input) {
        response = get(call(:base_uri, connection) + "/tasks/#{input['id']}").after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end&.[]("data")&.first
        call(:format_output, response, %w[parentIds superParentIds sharedIds responsibleIds authorIds followerIds superTaskIds subTaskIds dependencyIds])
        call(:strip_html_tags, response, input["strip_tags"], true)
        call(:format_custom_output, response)
      },

      output_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "id", "accountId", "title", "description", "briefDescription", "parentIds", "superParentIds", "sharedIds",
          "responsibleIds", "status", "importance", "createdDate", "updatedDate", "dates", "scope", "authorIds",
          "customStatusId", "hasAttachments", "attachmentCount", "permalink", "priority", "followedByMe", "followerIds", "superTaskIds",
          "subTaskIds", "dependencyIds", "metadata"
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection, input) {
        task_id = get(call(:base_uri, connection) + "/tasks?limit=1&sortField=UpdatedDate&sortOrder=Desc")&.[]("data")&.first&.[]("id")
        response = task_id.present? ? get(call(:base_uri, connection) + "/tasks/#{task_id}")&.[]("data")&.first : {}
        call(:format_output, response, %w[parentIds superParentIds sharedIds responsibleIds authorIds followerIds superTaskIds subTaskIds dependencyIds])
        if response["description"].present? && (input["strip_tags"].nil? || input["strip_tags"].is_true?)
          response["description"] = response["description"].strip_tags
        end
        call(:format_custom_output, response)
      }
    },

    search_task: {
      title: "Search tasks",
      description: 'Search <span class="provider">task</span> in <span class="provider">Wrike</span>',
      help: "Retrieves only tasks that match all the values entered in the filters below. " \
      "Search results are returned as a list of tasks. A maximum of 100 tasks can be returned.",

      config_fields: [
        {
          name: "custom_field_list",
          control_type: :select,
          label: "Search custom field",
          hint: "Select a custom field to search with",
          pick_list: "custom_fields",
          extends_schema: true
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom_field"].concat(
          object_definitions["task"].only(
            "title", "importance", "startDate", "dueDate", "scheduleDate", "updatedDate", "completedDate", "subTasks", "permalink", "type"
          )
        ).concat([{ name: "customStatuses", control_type: :multiselect, pick_list: :custom_statuses, sticky: true, hint: "Select custom statuses." },
                  { name: "status", hint: "Allowed values are <b>Active</b>, <b>Completed</b>, <b>Deferred</b> and <b>Cancelled</b>." },
                  { name: "created_after", type: :date_time, hint: "Search tasks created after this time" },
                  { name: "type", hint: "Retrieves tasks of specified type. Allowed values are <b>Backlog</b>, <b>Milestone</b>, and <b>Planned</b>." }])
      },

      execute: ->(connection, input) {
        input["createdDate"] = { start: input.delete("created_after").to_time.utc.iso8601 }.to_json if input["created_after"].present?
        input.each { |k, v| input[k] = { start: v.to_time.utc.iso8601 }.to_json if k.ends_with?("Date") }
        input = input.except("custom_field_list", "field_list")
        input["fields"] = '["recurrent","description","briefDescription","parentIds","superParentIds","sharedIds","responsibleIds","authorIds",' \
                          '"hasAttachments","attachmentCount","superTaskIds","subTaskIds","dependencyIds","metadata","customFields"]'
        res = get(call(:base_uri, connection) + "/tasks", input.compact).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end

        res["data"].each do |data|
          call(:format_response, data, connection)
        end
        res
      },

      output_fields: ->(object_definitions) {
        [
          { name: "data",
            label: "task",
            type: :array,
            of: :object,
            properties: object_definitions["task"].only(
              "id", "accountId", "title", "status", "importance", "createdDate", "updatedDate", "completedDate", "dates", "scope",
              "parentIds", "superParentIds", "sharedIds", "responsibleIds", "authorIds", "superTaskIds", "subTaskIds", "dependencyIds",
              "customStatusId", "custom_status", "permalink", "priority", "timelogHours"
            ).concat(object_definitions["custom"]) }
        ]
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/tasks?limit=1&sortField=UpdatedDate&sortOrder=Desc") || {}
      }
    },

    create_task: {
      description: 'Create <span class="provider">task</span> in <span class="provider">Wrike</span>',
      help: "Creates a task within a specified folder. Supports custom fields.",

      config_fields: [
        {
          name: "folder_id",
          label: "Folder",
          control_type: :select,
          pick_list: "folders",
          hint: "Select a folder to create task in. To use folder ID instead, toggle to 'Enter a folder ID'.",
          toggle_hint: "Select a folder",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a folder ID",
            name: "folder_id",
            control_type: :text,
            type: "string",
            hint: "Enter a folder ID. To choose a folder instead, toggle to 'Select a folder'.",
            label: "Folder ID",
            optional: false
          }
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be shown in the input and output. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "title", "description", "follow", "importance", "responsibles", "priorityAfter", "priorityBefore",
          "shareds", "parents", "followers", "superTasks", "metadata"
        ).required("title").concat(object_definitions["custom"]).concat(
          [
            { name: "dates", type: :object, properties: [
              { name: "type",
                hint: "Allowed values are <b>Backlog</b>, <b>Milestone</b>, and <b>Planned</b>." },
              { name: "start", type: :date_time, hint: "Should be present only in planned/milestone tasks.", render_input: :date_start_stop },
              { name: "due", type: :date_time, hint: "Should be present only in planned/milestone tasks.", render_input: :date_start_stop },
              { name: "workOnWeekends",
                hint: "Enter <b>true</b> using formula mode to include weekends. Defaults to <b>false</b>.",
                type: :boolean }
            ] }
          ]
        ).concat(
          [
            {
              name: "customStatus",
              control_type: :select,
              pick_list: :custom_statuses,
              sticky: true,
              label: "Custom status",
              hint: "Select custom status.",
              toggle_hint: "Select custom status",
              toggle_field: {
                toggle_hint: "Enter custom status name",
                name: "custom_status_name",
                label: "Custom status name",
                control_type: :text,
                optional: true,
                placeholder: "Default Workflow|On Hold",
                type: "string",
                hint: <<-HINT
                  Enter a custom status name with workflow name separated by <b>|</b>. E.g. <b>Default Workflow|On Hold</b>.
                  To select a custom status, toggle to 'Select custom status'.
                HINT
              }
            },
            { name: "status", hint: "Allowed values are <b>Active</b>, <b>Completed</b>, <b>Deferred</b> and <b>Cancelled</b>." }
          ]
        )
      },

      execute: ->(connection, input) {
        cs = call(:get_custom_statuses, connection, false)
        updated_input = input.reject { |k, _| %w[folder_id account_id field_list].include?(k) }
        input_custom_status_name = updated_input.delete("custom_status_name")
        updated_input["customStatus"] = call(:get_updated_custom_statuses, connection, input_custom_status_name, cs) if input_custom_status_name.present?
        if updated_input["customFields"].present?
          updated_input["customFields"] = updated_input["customFields"].map do |k, v|
            { "id" => k, "value" => v }
          end
        end
        call(:format_input, updated_input, %w[shareds parents responsibles followers superTasks])
        call(:payload_input, updated_input)
        updated_input["dates"] = updated_input["dates"].to_json if updated_input["dates"].present?
        task = post(call(:base_uri, connection) + "/folders/#{input['folder_id']}/tasks")
                 .payload(updated_input)
                 .request_format_www_form_urlencoded
                 .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                   error("#{message}: #{body}")
                 end&.[]("data")&.first
        call(:format_response, task, connection)
      },

      output_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "id", "accountId", "title", "description", "briefDescription", "parentIds", "superParentIds", "sharedIds", "responsibleIds", "status",
          "importance", "createdDate", "updatedDate", "dates", "scope", "authorIds", "customStatusId", "custom_status", "hasAttachments",
          "attachmentCount", "permalink", "priority", "followedByMe", "followerIds", "superTaskIds", "subTaskIds", "dependencyIds",
          "metadata", "completedDate"
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        task_id = get(call(:base_uri, connection) + "/tasks?limit=1&sortField=UpdatedDate&sortOrder=Desc")&.[]("data")&.first&.[]("id")
        response = task_id.present? ? get(call(:base_uri, connection) + "/tasks/#{task_id}")&.[]("data")&.first : {}
        call(:format_response, response, connection)
      }
    },

    update_task: {
      description: 'Update <span class="provider">task</span> in <span class="provider">Wrike</span>',
      help: "Updates a specified task by specifying a task ID. Also supports custom fields.",

      config_fields: [
        { name: "id", label: "Task ID", hint: "ID of task.", optional: false },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be shown in the input and output. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "title", "description", "importance", "priorityAfter", "priorityBefore", "follow", "addShareds", "metadata",
          "removeShareds", "addParents", "removeParents", "addResponsibles", "removeResponsibles", "addSuperTasks", "removeSuperTasks", "restore"
        ).concat(object_definitions["custom"]).concat(
          [
            {
              name: "dates", type: :object, properties: [
                { name: "type",
                  hint: "Allowed values are <b>Backlog</b>, <b>Milestone</b>, and <b>Planned</b>." },
                { name: "start", type: :date_time, hint: "Should be present only in planned/milestone tasks.", render_input: :date_start_stop },
                { name: "due", type: :date_time, hint: "Should be present only in planned/milestone tasks.", render_input: :date_start_stop },
                { name: "workOnWeekends",
                  hint: "Enter <b>true</b> with formula mode to include weekends. Defaults to <b>false</b>.",
                  type: :boolean }
              ]
            }
          ]
        ).concat(
          [
            {
              name: "customStatus",
              control_type: :select,
              pick_list: :custom_statuses,
              sticky: true,
              label: "Custom status",
              hint: "Select custom status.",
              toggle_hint: "Select custom status",
              toggle_field: {
                toggle_hint: "Enter custom status name",
                name: "custom_status_name",
                optional: true,
                label: "Custom status name",
                control_type: :text,
                type: "string",
                placeholder: "Default Workflow|On Hold",
                hint: <<-HINT
                  Enter a custom status name with workflow name separated by <b>|</b>. E.g. <b>Default Workflow|On Hold</b>.
                  To select a custom status, toggle to 'Select custom status'.
                HINT
              }
            },
            { name: "status", hint: "Allowed values are <b>Active</b>, <b>Completed</b>, <b>Deferred</b> and <b>Cancelled</b>." }
          ]
        )
      },

      execute: ->(connection, input) {
        cs = call(:get_custom_statuses, connection, false)
        updated_input = input.except("id", "account_id", "field_list")
        input_custom_status_name = updated_input.delete("custom_status_name")
        updated_input["customStatus"] = call(:get_updated_custom_statuses, connection, input_custom_status_name, cs) if input_custom_status_name.present?
        if updated_input["customFields"].present?
          updated_input["customFields"] = updated_input["customFields"].map do |k, v|
            { "id" => k, "value" => v }
          end
        end
        call(:format_input, updated_input, %w[addShareds removeShareds addParents removeParents addResponsibles removeResponsibles addSuperTasks removeSuperTasks])
        payload = call(:payload_input, updated_input)
        payload = payload.merge("dates" => updated_input["dates"].to_json) if updated_input["dates"].present?
        task = put(call(:base_uri, connection) + "/tasks/#{input['id']}").payload(payload)
                 .request_format_www_form_urlencoded
                 .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                   error("#{message}: #{body}")
                 end&.[]("data")&.first
        call(:format_response, task, connection)
      },

      output_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "id", "accountId", "title", "description", "briefDescription", "parentIds", "superParentIds", "sharedIds", "completedDate",
          "responsibleIds", "status", "importance", "createdDate", "updatedDate", "dates", "scope", "authorIds", "customStatusId", "custom_status",
          "hasAttachments", "attachmentCount", "permalink", "priority", "followedByMe", "followerIds", "superTaskIds", "subTaskIds",
          "dependencyIds", "metadata"
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        task_id = get(call(:base_uri, connection) + "/tasks?limit=1&sortField=UpdatedDate&sortOrder=Desc")&.[]("data")&.first&.[]("id")
        response = task_id.present? ? get(call(:base_uri, connection) + "/tasks/#{task_id}")&.[]("data")&.first : {}
        call(:format_response, response, connection)
      }
    },

    list_users: {
      description: 'List <span class="provider">users</span> in <span class="provider">Wrike</span>',
      help: "Retrieves the full list of users in connected account. User IDs may be used in subsequent Wrike actions.",

      execute: ->(connection) {
        get(call(:base_uri, connection) + "/contacts").after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end
      },

      output_fields: ->(object_definitions) {
        [
          { name: "data", label: "Users", type: :array, of: :object, properties: object_definitions["contact"] }
        ]
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/contacts?me=true")
      }
    },

    create_comment_in_task: {
      description: 'Create <span class="provider">comment in task</span> in <span class="provider">Wrike</span>',
      help: "Creates a comment in a task. Enter a task ID to add the comment to.",

      input_fields: -> {
        [
          { name: "id", label: "Task ID", hint: "ID of task to create comment in.", optional: false },
          { name: "text", label: "Comment", hint: "Comment text.", optional: false }
        ]
      },

      execute: ->(connection, input) {
        post(call(:base_uri, connection) + "/tasks/#{input.delete('id')}/comments").params(input).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end&.[]("data")&.first
      },

      output_fields: ->(object_definitions) {
        object_definitions["comment"].only("id", "authorId", "text", "updatedDate", "createdDate", "taskId")
      },

      sample_output: ->(connection) {
        task_id = get(call(:base_uri, connection) + "/tasks?limit=1&sortField=UpdatedDate&sortOrder=Desc")&.[]("data")&.first&.[]("id")
        task_id.present? ? (get(call(:base_uri, connection) + "/tasks/#{task_id}/comments")&.[]("data")&.first || {}) : {}
      }
    },

    create_comment_in_folder: {
      description: 'Create <span class="provider">comment in folder</span> in <span class="provider">Wrike</span>',
      help: "Creates a comment in a folder. Select a folder or enter a folder ID to add the comment to.",

      input_fields: -> {
        [
          {
            name: "folder_id",
            label: "Folder",
            control_type: :select,
            pick_list: "folders",
            hint: "Select a folder to create comment in. To use folder ID instead, toggle to 'Enter a folder ID'.",
            toggle_hint: "Select a folder",
            optional: false,
            toggle_field: {
              toggle_hint: "Enter a folder ID",
              name: "folder_id",
              control_type: :text,
              type: "string",
              hint: "Enter a folder ID. To choose a folder instead, toggle to 'Select a folder'.",
              label: "Folder ID",
              optional: false
            }
          },
          { name: "text", label: "Comment", hint: "Comment text.", optional: false }
        ]
      },

      execute: ->(connection, input) {
        post(call(:base_uri, connection) + "/folders/#{input.delete('folder_id')}/comments").params(input).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end&.[]("data")&.first
      },

      output_fields: ->(object_definitions) {
        object_definitions["comment"].only("id", "authorId", "text", "updatedDate", "createdDate", "folderId")
      },

      sample_output: ->(connection) {
        folder_id = get(call(:base_uri, connection) + "/folders?descendants=false")&.[]("data")&.last&.[]("id")
        folder_id.present? ? (get(call(:base_uri, connection) + "/folders/#{folder_id}/comments")&.[]("data")&.first || {}) : {}
      }
    },

    get_folder_by_id: {
      description: 'Get <span class="provider">folder</span> by ID in <span class="provider">Wrike</span>',
      help: "Retrieves folder/project info and metadata by specifying folder ID or selecting a folder. Also shows custom fields.",

      config_fields: [
        {
          name: "id",
          label: "Folder",
          pick_list: "folders",
          control_type: :select,
          hint: "Select a folder to retrieve. To use folder ID instead, toggle to 'Enter a folder ID'.",
          toggle_hint: "Select a folder",
          optional: false,
          toggle_field: { toggle_hint: "Enter a folder ID", name: "id", control_type: :text, type: "string", label: "Folder ID", optional: false }
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: true,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      execute: ->(connection, input) {
        response = get(call(:base_uri, connection) + "/folders/#{input['id']}").after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end&.[]("data")&.first
        call(:strip_html_tags, response, input["strip_tags"], true)
        call(:format_output, response, %w[parentIds superParentIds sharedIds childIds])
        call(:format_output, response["project"], %w[ownerIds]) if response["project"].present?
        call(:format_custom_output, response)
      },

      output_fields: ->(object_definitions) {
        object_definitions["folder"].only(
          "id", "accountId", "title", "description", "parentIds", "superParentIds", "sharedIds", "childIds", "scope",
          "createdDate", "updatedDate", "hasAttachments", "permalink", "workflowId", "metadata", "project"
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection, input) {
        folder_id = get(call(:base_uri, connection) + "/folders?descendants=false")&.[]("data")&.last&.[]("id")
        folder_id.present? ? folder = get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : {}
        call(:strip_html_tags, folder, input["strip_tags"], true)
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      }
    },

    create_timelog: {
      description: 'Create <span class="provider">timelog record for task</span> in <span class="provider">Wrike</span>',
      title_hint: "Create timelog record for task in Wrike",
      help: "This action creates a timelog for a specified task in Wrike.",

      input_fields: -> {
        [
          { name: "taskId", optional: false, label: "ID of task to add new timelog to", hint: "Add new timelog record to specified task." },
          { name: "comment", label: "Timelog comment", hint: "Add comment to this timelog record." },
          { name: "hours", optional: false, type: :number, label: "Timelog tracked hours", hint: "Number of tracked hours to add to this timelog." },
          { name: "trackedDate", optional: false, type: :date, hint: "Date to register for this timelog" },
          { name: "categoryId", control_type: :select, pick_list: :timelog_categories, label: "Timelog category", hint: "Assign a timelog category to this timelog." }
        ]
      },

      execute: ->(connection, input) {
        post(call(:base_uri, connection) + "/tasks/#{input.delete('taskId')}/timelogs").params(input).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end&.[]("data")&.first
      },

      output_fields: ->(object_definitions) {
        object_definitions["timelog"]
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/timelogs")["data"]&.last || {}
      }
    },

    update_timelog: {
      description: 'Update <span class="provider">timelog record for task</span> in <span class="provider">Wrike</span>',
      title_hint: "Update timelog record for task in Wrike",
      help: "This action updates a timelog for a specified task in Wrike.",

      input_fields: -> {
        [
          { name: "id", optional: false, label: "ID of timelog to update", hint: "Timelog to update." },
          { name: "comment", label: "Timelog comment", hint: "New timelog comment to update with." },
          { name: "hours", type: :number, label: "Timelog tracked hours", hint: "New timelog tracked hours to update." },
          { name: "trackedDate", type: :date, hint: "New timelog date to update." },
          { name: "categoryId", control_type: :select, pick_list: :timelog_categories, label: "Timelog category", hint: "Update the assigned timelog category for this timelog." }
        ]
      },

      execute: ->(connection, input) {
        put(call(:base_uri, connection) + "/timelogs/#{input.delete('id')}").params(input).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end&.[]("data")&.first
      },

      output_fields: ->(object_definitions) {
        object_definitions["timelog"]
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/timelogs")["data"]&.last || {}
      }
    },

    search_timelog: {
      title: "Search timelogs",
      description: 'Search <span class="provider">timelogs</span> in <span class="provider">Wrike</span>',
      title_hint: "Search for timelogs in Wrike account.",
      help: "This action returns timelogs that match all the values entered in the fields below.",

      input_fields: -> {
        [
          {
            name: "timelogCategories",
            control_type: :multiselect,
            pick_list: :timelog_categories,
            delimiter: ",",
            label: "Timelog category",
            hint: "Return only timelogs of the specified timelog category."
          },
          {
            name: "createdDate",
            type: :date_time,
            sticky: true,
            hint: "Retrieve timelogs created after this date."
          },
          {
            name: "updatedDate",
            type: :date_time,
            hint: "Retrieve timelogs updated after this date."
          },
          {
            name: "trackedDate",
            type: :date,
            hint: "Retrieve timelogs tracked after this date."
          },
          # {
          #   name: 'me',
          #   type: :boolean,
          #   label: "Retrieve timelogs created by you only?",
          #   hint: "Choose Yes to retrieve timelogs created only by you. Defaults to No."
          # },
          {
            name: "descendants",
            type: :boolean,
            control_type: :checkbox,
            label: "Add all descendant tasks to search scope?",
            hint: "Choose <b>Yes</b> to retrieve timelogs found in descendant tasks. Defaults to <b>No</b>."
          }
          # {
          #   name: 'subTasks',
          #   type: :boolean,
          #   label: "Add subtasks to search scope?",
          #   hint: "Choose Yes to retrieve timelogs found in subtasks. Defaults to No. Enter true in formula mode to retrieve timelogs found in subtasks. Defaults to false."
          # }
        ]
      },

      execute: ->(connection, input) {
        params = input.merge(
          input.each_with_object({}) do |(k, v), h|
            if ["createdDate", "updatedDate"].include?(k)
              h[k] = "{'start':'#{v.to_time.utc.iso8601}'}"
            elsif k == "trackedDate"
              h[k] = "{'start':'#{v}'}"
            elsif k == "timelogCategories"
              h[k] = v.split(",").to_s
            end
          end
        )
        get(call(:base_uri, connection) + "/timelogs", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end
      },

      output_fields: ->(object_definitions) {
        [{ name: "data", type: :array, of: :object, properties: object_definitions["timelog"] }]
      },

      sample_output: ->(connection) {
        { data: Array.wrap(get(call(:base_uri, connection) + "/timelogs")["data"]&.last) } || {}
      }
    },

    create_folder: {
      label: "Create folder",
      title: "Create folder",
      description: "Create <span class='provider'>folder</span> in <span class='provider'>Wrike</span>",
      help: "Creates a folder within a specified folder/project. You can also add users to share the folder with.",

      config_fields: [
        {
          name: "folder_id",
          label: "Parent folder/project",
          control_type: :select,
          pick_list: "folders",
          hint: "Select a parent folder/project to create this folder in. To use folder/project ID instead, toggle to 'Enter a folder/project ID'.",
          toggle_hint: "Select a parent folder/project",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a folder/project ID",
            name: "folder_id",
            control_type: :text,
            type: "string",
            hint: "Enter a folder/project ID. To select a folder/project instead, toggle to 'Select a folder/project'.",
            label: "Folder/project ID",
            optional: false
          }
        },
        { name: "title", type: :string, hint: "Title of folder.", control_type: :text, optional: false },
        { name: "description", type: :string, hint: "Description of folder.", sticky: true, control_type: :text },
        { name: "shareds", label: "Users who share the folder", type: :array, properties: [
          { name: "id", label: "User ID", hint: "User ID of user to share folder with." }
        ] },
        { name: "metadata", type: :array, of: :object, properties: [
          { name: "key", hint: "Key can be of alphanumeric values with maximum length up to 50 characters." },
          { name: "value", hint: "Metadata field value." }
        ] },
        {
          name: "project",
          type: :object,
          sticky: true,
          optional: true,
          hint: "To create a project instead of a folder, these <b>Project</b> fields should have values.",
          properties: [
            {
              name: "status",
              sticky: true,
              optional: true,
              hint: "Case sensitive status value. Allowed values are <b>Green</b>, <b>Yellow</b>, <b>Red</b>, <b>Completed</b>, " \
              "<b>OnHold</b>, and <b>Cancelled</b>."
            },
            {
              name: "customStatus",
              control_type: :select,
              pick_list: :custom_statuses,
              sticky: true,
              label: "Custom status",
              hint: "Select custom status.",
              toggle_hint: "Select custom status",
              toggle_field: {
                toggle_hint: "Enter custom status name",
                name: "custom_status_name",
                label: "Custom status name",
                optional: true,
                control_type: :text,
                placeholder: "Default Workflow|On Hold",
                type: "string",
                hint: <<-HINT
                  Enter workflow name and custom status name separated by <b>|</b>. E.g. <b>Default Workflow|On Hold</b>.
                  To select a custom status, toggle to 'Select custom status'.
                HINT
              }
            },
            { name: "ownerIds", sticky: true, label: "User IDs of Wrike users who should own this folder",
              type: :array,
              properties: [{ name: "id", sticky: true, label: "User ID", hint: "User ID of project owner." }] },
            { name: "startDate", optional: false, sticky: true, type: :date, hint: "Start date of project.", render_input: :date_input },
            { name: "endDate", optional: false, sticky: true, type: :date, hint: "End date of project.", render_input: :date_input }
          ]
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be shown in the input and output. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom"]
      },

      execute: ->(connection, input) {
        updated_input = input.except("folder_id", "account_id", "field_list")
        if updated_input["customFields"].present?
          updated_input["customFields"] = updated_input["customFields"].map do |k, v|
            { "id" => k, "value" => v }
          end
        end
        cs = call(:get_custom_statuses, connection, false)
        input_custom_status_name = updated_input.dig("project", "custom_status_name")
        if input_custom_status_name.present?
          updated_input["project"]["customStatus"] = call(:get_updated_custom_statuses, connection, input_custom_status_name, cs)
        end
        call(:format_input, updated_input, %w[shareds])
        call(:format_input, updated_input["project"], %w[ownerIds]) if updated_input["project"].present?
        payload = call(:payload_input, updated_input)
        payload = payload.merge("project" => updated_input["project"].to_json) if updated_input["project"].present?
        folder = post(call(:base_uri, connection) + "/folders/#{input['folder_id']}/folders")
                   .payload(payload)
                   .request_format_www_form_urlencoded
                   .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                     error("#{message}: #{body}")
                   end&.[]("data")&.first
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'folder'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds",
            "parentIds", "childIds", "superParentIds", "scope", "hasAttachments", "permalink",
            "workflowId", "metadata", "project"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        params = { descendants: false }
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        folder = folder_id.present? ? get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : {}
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      }
    },

    create_project: {
      label: "Create project",
      title: "Create project",
      description: "Create <span class='provider'>project</span> in <span class='provider'>Wrike</span>",
      help: "Creates a project within a specified folder/project. You can also add users to share the project with.",

      config_fields: [
        {
          name: "folder_id",
          label: "Parent folder/project",
          control_type: :select,
          pick_list: "folders",
          hint: "Select a parent folder/project to create this project in. To use folder/project ID instead, toggle to 'Enter a folder/project ID'.",
          toggle_hint: "Select a parent folder/project",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a folder/project ID",
            name: "folder_id",
            control_type: :text,
            type: "string",
            hint: "Enter a folder/project ID. To select a folder/project instead, toggle to 'Select a folder/project'.",
            label: "Folder/project ID",
            optional: false
          }
        },
        { name: "title", type: :string, hint: "Title of project.", control_type: :text, optional: false },
        { name: "description", type: :string, hint: "Description of project.", sticky: true, control_type: :text },
        { name: "shareds", label: "Users who share the project", type: :array, properties: [
          { name: "id", label: "User ID", hint: "User ID of user to share project with." }
        ] },
        { name: "metadata", type: :array, of: :object, properties: [
          { name: "key", hint: "Key can be of alphanumeric values with maximum length up to 50 characters." },
          { name: "value", hint: "Metadata field value." }
        ] },
        {
          name: "project",
          type: :object,
          sticky: true,
          optional: false,
          hint: "Enter project details",
          properties: [
            {
              name: "status",
              sticky: true,
              optional: true,
              hint: "Case sensitive status value. Allowed values are <b>Green</b>, <b>Yellow</b>, <b>Red</b>, <b>Completed</b>, " \
              "<b>OnHold</b>, and <b>Cancelled</b>."
            },
            {
              name: "customStatus",
              control_type: :select,
              pick_list: :custom_statuses,
              sticky: true,
              label: "Custom status",
              hint: "Select custom status.",
              toggle_hint: "Select custom status",
              toggle_field: {
                toggle_hint: "Enter custom status name",
                name: "custom_status_name",
                label: "Custom status name",
                optional: true,
                control_type: :text,
                placeholder: "Default Workflow|On Hold",
                type: "string",
                hint: <<-HINT
                  Enter workflow name and custom status name separated by <b>|</b>. E.g. <b>Default Workflow|On Hold</b>.
                  To select a custom status, toggle to 'Select custom status'.
                HINT
              }
            },
            { name: "ownerIds", sticky: true, label: "User IDs of Wrike users who should own this project",
              type: :array,
              properties: [{ name: "id", sticky: true, label: "User ID", hint: "User ID of project owner." }] },
            { name: "startDate", optional: false, sticky: true, type: :date, hint: "Start date of project.", render_input: :date_input },
            { name: "endDate", optional: false, sticky: true, type: :date, hint: "End date of project.", render_input: :date_input }
          ]
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be shown in the input and output. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom"]
      },

      execute: ->(connection, input) {
        updated_input = input.except("folder_id", "account_id", "field_list")
        if updated_input["customFields"].present?
          updated_input["customFields"] = updated_input["customFields"].map do |k, v|
            { "id" => k, "value" => v }
          end
        end
        cs = call(:get_custom_statuses, connection, false)
        input_custom_status_name = updated_input.dig("project", "custom_status_name")
        if input_custom_status_name.present?
          updated_input["project"]["customStatus"] = call(:get_updated_custom_statuses, connection, input_custom_status_name, cs)
        end
        call(:format_input, updated_input, %w[shareds])
        call(:format_input, updated_input["project"], %w[ownerIds]) if updated_input["project"].present?
        payload = call(:payload_input, updated_input)
        payload = payload.merge("project" => updated_input["project"].to_json) if updated_input["project"].present?
        folder = post(call("base_uri", connection) + "/folders/#{input['folder_id']}/folders")
                   .payload(payload)
                   .request_format_www_form_urlencoded
                   .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                     error("#{message}: #{body}")
                   end&.[]("data")&.first
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'project'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds",
            "parentIds", "childIds", "superParentIds", "scope", "hasAttachments", "permalink",
            "workflowId", "metadata", "project"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        params = { descendants: true }
        params["project"] = true
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        folder = folder_id.present? ? get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : {}
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      }
    },

    update_folder: {
      title: "Update folder",
      description: "Update <span class='provider'>folder</span> in <span class='provider'>Wrike</span>",
      help: "Updates a folder within a specified folder/project. You can also add users to share the folder with.",

      config_fields: [
        {
          name: "id",
          label: "folder".labelize,
          pick_list: "folders",
          control_type: :select,
          hint: "Select a folder to update. To use folder ID instead, toggle to 'Enter a folder ID'.",
          toggle_hint: "Select a folder",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a folder ID",
            name: "id",
            control_type: :text,
            type: "string",
            label: "#{'folder'.labelize} ID",
            optional: false,
            hint: "Enter a folder ID. To select a folder instead, toggle to 'Select a folder'."
          }
        },
        { name: "title", type: :string, hint: "Title of folder.", control_type: :text, optional: true },
        { name: "description", type: :string, hint: "Description of folder.", sticky: true, control_type: :text },
        { name: "addShareds", label: "Users to share the folder with", type: :array, properties: [
          { name: "id", label: "User ID", hint: "User ID of user to share folder with." }
        ] },
        { name: "removeShareds", label: "Remove users from sharing of folder", type: :array, properties: [
          { name: "id", label: "User ID", hint: "User ID of user to remove sharing of this folder." }
        ] },
        { name: "removeParents", label: "Remove parent folders/projects", type: :array, properties: [
          { name: "id", label: "Folder/project ID", hint: "Folder/proect IDs of parent folders/projects to remove. Cannot contain rootFolderId and recycleBinId." }
        ] },
        { name: "addParents", label: "Add parent folders/projects", type: :array, properties: [
          { name: "id", label: "Folder/project ID", hint: "Folder/project IDs of parent folders/projects to add. Cannot contain rootFolderId and recycleBinId." }
        ] },
        { name: "metadata", type: :array, of: :object, properties: [
          { name: "key", hint: "Key can be of alphanumeric values with maximum length up to 50 characters." },
          { name: "value", hint: "Metadata field value." }
        ] },
        { name: "restore",
          type: :boolean,
          hint: "Choose <b>Yes</b> to restore project from recycle bin. Defaults to <b>No</b>." },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be shown in the input and output. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom"].concat(
          [
            { name: "project", type: :object, sticky: false, properties: [
              { name: "status", sticky: false,
                hint: "Case sensitive status value. Allowed values are <b>Green</b>, <b>Yellow</b>, <b>Red</b>, <b>Completed</b>, <b>OnHold</b>, and <b>Cancelled</b>." },
              {
                name: "customStatus",
                control_type: :select,
                pick_list: :custom_statuses,
                sticky: true,
                label: "Custom status",
                hint: "Select custom status.",
                toggle_hint: "Select custom status",
                toggle_field: {
                  toggle_hint: "Enter custom status name",
                  name: "custom_status_name",
                  label: "Custom status name",
                  control_type: :text,
                  optional: true,
                  placeholder: "Default Workflow|On Hold",
                  type: "string",
                  hint: <<-HINT
                    Enter workflow name and custom status name separated by <b>|</b>. E.g. <b>Default Workflow|On Hold</b>.
                    To select a custom status, toggle to 'Select custom status'.
                  HINT
                }
              },
              { name: "ownersAdd", label: "Add owner ID", sticky: false, type: :array, properties: [
                { name: "id", sticky: false, label: "User ID", hint: "User ID of folder owner to add." }
              ] },
              { name: "ownersRemove", sticky: false, label: "Remove owner ID", type: :array, properties: [
                { name: "id", sticky: false, label: "User ID", hint: "User ID of folder owner to remove." }
              ] },
              { name: "startDate", sticky: false, hint: "Start date of project.", type: :date, render_input: :date_input },
              { name: "endDate", sticky: false, hint: "End date of project.", type: :date, render_input: :date_input }
            ] }
          ]
        )
      },

      execute: ->(connection, input) {
        updated_input = input.except("id", "account_id", "field_list")
        if updated_input["customFields"].present?
          updated_input["customFields"] = updated_input["customFields"].map do |k, v|
            { "id" => k, "value" => v }
          end
        end
        cs = call(:get_custom_statuses, connection, false)
        input_custom_status_name = updated_input.dig("project", "custom_status_name")
        if input_custom_status_name.present?
          updated_input["project"]["customStatus"] = call(:get_updated_custom_statuses, connection, input_custom_status_name, cs)
        end
        call(:format_input, updated_input, %w[addParents removeParents addShareds removeShareds])
        call(:format_input, updated_input["project"], %w[ownersAdd ownersRemove]) if updated_input["project"].present?
        payload = call(:payload_input, updated_input)
        payload = payload.merge("project" => updated_input["project"].to_json) if updated_input["project"].present?
        folder = put(call(:base_uri, connection) + "/folders/#{input['id']}")
                   .payload(payload)
                   .request_format_www_form_urlencoded
                   .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                     error("#{message}: #{body}")
                   end&.[]("data")&.first
        folder["description"] = folder["description"].strip_tags if folder["description"].present?
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'folder'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds",
            "parentIds", "childIds", "superParentIds", "scope", "hasAttachments", "permalink",
            "workflowId", "metadata", "customFields", "project"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        params = { descendants: false }
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        folder = folder_id.present? ? get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : {}
        folder["description"] = folder["description"].strip_tags if folder["description"].present?
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      }
    },

    update_project: {
      title: "Update project",
      description: "Update <span class='provider'>project</span> in <span class='provider'>Wrike</span>",
      help: "Updates a project within a specified folder/project. You can also add users to share the project with.",

      config_fields: [
        {
          name: "id",
          label: "project".labelize,
          pick_list: "folders",
          control_type: :select,
          hint: "Select a project to update. To use project ID instead, toggle to 'Enter a project ID'.",
          toggle_hint: "Select a project",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a project ID",
            name: "id",
            control_type: :text,
            type: "string",
            label: "#{'project'.labelize} ID",
            optional: false,
            hint: "Enter a project ID. To select a project instead, toggle to 'Select a project'."
          }
        },
        { name: "title", type: :string, hint: "Title of project.", control_type: :text, optional: true },
        { name: "description", type: :string, hint: "Description of project.", sticky: true, control_type: :text },
        { name: "addShareds", label: "Users to share the project with", type: :array, properties: [
          { name: "id", label: "User ID", hint: "User ID of user to share project with." }
        ] },
        { name: "removeShareds", label: "Remove users from sharing of project", type: :array, properties: [
          { name: "id", label: "User ID", hint: "User ID of user to remove sharing of this project." }
        ] },
        { name: "removeParents", label: "Remove parent folders/projects", type: :array, properties: [
          { name: "id", label: "Folder/project ID", hint: "Folder/proect IDs of parent folders/projects to remove. Cannot contain rootFolderId and recycleBinId." }
        ] },
        { name: "addParents", label: "Add parent folders/projects", type: :array, properties: [
          { name: "id", label: "Folder/project ID", hint: "Folder/project IDs of parent folders/projects to add. Cannot contain rootFolderId and recycleBinId." }
        ] },
        { name: "metadata", type: :array, of: :object, properties: [
          { name: "key", hint: "Key can be of alphanumeric values with maximum length up to 50 characters." },
          { name: "value", hint: "Metadata field value." }
        ] },
        { name: "restore",
          type: :boolean,
          hint: "Choose <b>Yes</b> to restore project from recycle bin. Defaults to <b>No</b>." },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be shown in the input and output. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom"].concat(
          [
            { name: "project", type: :object, sticky: true, properties: [
              { name: "status", sticky: true,
                hint: "Case sensitive status value. Allowed values are <b>Green</b>, <b>Yellow</b>, <b>Red</b>, <b>Completed</b>, <b>OnHold</b>, and <b>Cancelled</b>." },
              {
                name: "customStatus",
                control_type: :select,
                pick_list: :custom_statuses,
                sticky: true,
                label: "Custom status",
                hint: "Select custom status.",
                toggle_hint: "Select custom status",
                toggle_field: {
                  toggle_hint: "Enter custom status name",
                  name: "custom_status_name",
                  label: "Custom status name",
                  control_type: :text,
                  optional: true,
                  placeholder: "Default Workflow|On Hold",
                  type: "string",
                  hint: <<-HINT
                    Enter workflow name and custom status name separated by <b>|</b>. E.g. <b>Default Workflow|On Hold</b>.
                    To select a custom status, toggle to 'Select custom status'.
                  HINT
                }
              },
              { name: "ownersAdd", label: "Add owner ID", sticky: true, type: :array, properties: [
                { name: "id", sticky: true, label: "User ID", hint: "User ID of project owner to add." }
              ] },
              { name: "ownersRemove", sticky: true, label: "Remove owner ID", type: :array, properties: [
                { name: "id", sticky: true, label: "User ID", hint: "User ID of project owner to remove." }
              ] },
              { name: "startDate", sticky: true, hint: "Start date of project.", type: :date, render_input: :date_input },
              { name: "endDate", sticky: true, hint: "End date of project.", type: :date, render_input: :date_input }
            ] }
          ]
        )
      },

      execute: ->(connection, input) {
        updated_input = input.except("id", "account_id", "field_list")
        if updated_input["customFields"].present?
          updated_input["customFields"] = updated_input["customFields"].map do |k, v|
            { "id" => k, "value" => v }
          end
        end
        cs = call(:get_custom_statuses, connection, false)
        input_custom_status_name = updated_input.dig("project", "custom_status_name")
        if input_custom_status_name.present?
          updated_input["project"]["customStatus"] = call(:get_updated_custom_statuses, connection, input_custom_status_name, cs)
        end
        call(:format_input, updated_input, %w[addParents removeParents addShareds removeShareds])
        call(:format_input, updated_input["project"], %w[ownersAdd ownersRemove]) if updated_input["project"].present?
        payload = call(:payload_input, updated_input)
        payload = payload.merge("project" => updated_input["project"].to_json) if updated_input["project"].present?
        folder = put(call(:base_uri, connection) + "/folders/#{input['id']}")
                   .payload(payload)
                   .request_format_www_form_urlencoded
                   .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                     error("#{message}: #{body}")
                   end&.[]("data")&.first
        folder["description"] = folder["description"].strip_tags if folder["description"].present?
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'project'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds",
            "parentIds", "childIds", "superParentIds", "scope", "hasAttachments", "permalink",
            "workflowId", "metadata", "customFields", "project"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        params = { descendants: true }
        params["project"] = true
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        folder = folder_id.present? ? get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : {}
        folder["description"] = folder["description"].strip_tags if folder["description"].present?
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      }
    },

    search_folder: {
      title: "Search #{'folder'.pluralize}",
      description: "Search <span class='provider'>#{'folder'.pluralize}</span> in <span class='provider'>Wrike</span>",
      help: "Retrieves only #{'folder'.pluralize} that match all values entered in the filters below. " \
      "Search results are returned as a list of folder. A maximum of 100 #{'folder'.pluralize} can be returned.",

      config_fields: [
        {
          name: "custom_field_list",
          control_type: :select,
          label: "Search custom field",
          hint: "Select a custom field you want to filter with",
          pick_list: "custom_fields",
          extends_schema: true,
          sticky: true
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: true,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom_field"].concat(
          object_definitions["folder"].only("metadata")
        ).concat(
          [
            { name: "permalink",
              hint: "Retrieves folders matching this permalink. " \
              "Can be found in folder page, get permalink by hovering over permalink icon." },
            { name: "descendants", type: :boolean, control_type: :checkbox, hint: "Adds all descendant #{'folder'.pluralize} to search scope.", optional: true },
            {
              name: "deleted",
              label: "Retrieve deleted #{'folder'.pluralize} only?",
              type: :boolean,
              hint: "Enter <b>true</b> using formula mode to return deleted #{'folder'.pluralize} only. Default value is <b>false</b>."
            },
            {
              name: "updatedDate",
              type: :date_time,
              sticky: true,
              hint: "Retrieve #{'folder'.pluralize} updated after this date and time."
            }
          ]
        )
      },

      execute: ->(connection, input) {
        input["updatedDate"] = { start: input["updatedDate"].to_time.utc.iso8601 }.to_json if input["updatedDate"].present?
        input = input.except("custom_field_list", "field_list")
        input["fields"] = "['description','briefDescription','customFields','metadata','hasAttachments','attachmentCount','superParentIds','customColumnIds']"
        folders = get(call(:base_uri, connection) + "/folders").params(input.except("strip_tags").compact).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end
        folders&.[]("data")&.each do |k|
          call(:strip_html_tags, k, input["strip_tags"], true)
          call(:format_output, k, %w[sharedIds parentIds childIds superParentIds])
          call(:format_output, k["project"], %w[ownerIds]) if k["project"].present?
          call(:format_custom_output, k)
        end
        folders.except("kind")
      },

      output_fields: ->(object_definitions) {
        [
          {
            name: "data",
            label: "folder".pluralize.labelize,
            type: :array,
            of: :object,
            properties: [
              { name: "id", label: "#{'folder'.labelize} ID" }
            ].concat(
              object_definitions["folder"].only(
                "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
                "briefDescription", "superParentIds", "hasAttachments", "attachmentCount", "metadata", "customColumnIds",
                "childIds", "scope", "permalink", "workflowId", "project"
              )
            ).concat(object_definitions["custom"])
          }
        ]
      },

      sample_output: ->(connection, input) {
        params = { descendants: false }
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        permalink = get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first&.[]("permalink")
        folders = permalink.present? ? get(call(:base_uri, connection) + "/folders?permalink=#{permalink}") : {}
        folders&.[]("data")&.each do |k|
          call(:strip_html_tags, k, input["strip_tags"], false)
          call(:format_output, k, %w[sharedIds parentIds childIds])
          call(:format_output, k["project"], %w[ownerIds]) if k["project"].present?
        end
        folders
      }
    },

    search_project: {
      title: "Search #{'project'.pluralize}",
      description: "Search <span class='provider'>#{'project'.pluralize}</span> in <span class='provider'>Wrike</span>",
      help: "Retrieves only #{'project'.pluralize} that match all values entered in the filters below. " \
      "Search results are returned as a list of project. A maximum of 100 #{'project'.pluralize} can be returned.",

      config_fields: [
        {
          name: "custom_field_list",
          control_type: :select,
          label: "Search custom field",
          hint: "Select a custom field you want to filter with",
          pick_list: "custom_fields",
          extends_schema: true,
          sticky: true
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: true,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      input_fields: ->(object_definitions) {
        object_definitions["custom_field"].concat(
          object_definitions["folder"].only("metadata")
        ).concat(
          [
            { name: "permalink",
              hint: "Retrieves folders matching this permalink. " \
              "Can be found in project page, get permalink by hovering over permalink icon." },
            { name: "descendants", type: :boolean, control_type: :checkbox, hint: "Adds all descendant #{'project'.pluralize} to search scope.", optional: true },
            {
              name: "deleted",
              label: "Retrieve deleted #{'project'.pluralize} only?",
              type: :boolean,
              hint: "Enter <b>true</b> using formula mode to return deleted #{'project'.pluralize} only. Default value is <b>false</b>."
            },
            {
              name: "updatedDate",
              type: :date_time,
              sticky: true,
              hint: "Retrieve #{'project'.pluralize} updated after this date and time."
            }
          ]
        )
      },

      execute: ->(connection, input) {
        input["updatedDate"] = { start: input["updatedDate"].to_time.utc.iso8601 }.to_json if input["updatedDate"].present?
        input = input.except("custom_field_list", "field_list")
        input["fields"] = "['description','briefDescription','customFields','metadata','hasAttachments','attachmentCount','superParentIds','customColumnIds']"
        input["project"] = true
        folders = get(call(:base_uri, connection) + "/folders").params(input.except("strip_tags").compact).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end
        folders&.[]("data")&.each do |k|
          call(:strip_html_tags, k, input["strip_tags"], true)
          call(:format_output, k, %w[sharedIds parentIds childIds superParentIds])
          call(:format_output, k["project"], %w[ownerIds]) if k["project"].present?
          call(:format_custom_output, k)
        end
        folders.except("kind")
      },

      output_fields: ->(object_definitions) {
        [
          {
            name: "data",
            label: "project".pluralize.labelize,
            type: :array,
            of: :object,
            properties: [
              { name: "id", label: "#{'project'.labelize} ID" }
            ].concat(
              object_definitions["folder"].only(
                "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
                "briefDescription", "superParentIds", "hasAttachments", "attachmentCount", "metadata", "customColumnIds",
                "childIds", "scope", "permalink", "workflowId", "project"
              )
            ).concat(object_definitions["custom"])
          }
        ]
      },

      sample_output: ->(connection, input) {
        params = { descendants: true }
        params["project"] = true
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        permalink = get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first&.[]("permalink")
        folders = permalink.present? ? get(call(:base_uri, connection) + "/folders?permalink=#{permalink}") : {}
        folders&.[]("data")&.each do |k|
          call(:strip_html_tags, k, input["strip_tags"], false)
          call(:format_output, k, %w[sharedIds parentIds childIds])
          call(:format_output, k["project"], %w[ownerIds]) if k["project"].present?
        end
        folders
      }
    },

    copy_folder: {
      description: "Copy <span class='provider'>folder</span> in <span class='provider'>Wrike</span>",
      help: "Copies an existing folder within a specified folder/project. You can also add users to share the folder with.",

      config_fields: [
        {
          name: "id",
          label: "#{'folder'.labelize} to be copied",
          pick_list: "folders",
          control_type: :select,
          hint: "Select a folder to be copied. To use the folder's ID instead, toggle to 'Enter a folder ID'.",
          toggle_hint: "Select a folder",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a folder ID",
            name: "id",
            control_type: :text,
            type: "string",
            hint: "Enter a folder's ID. To select a folder instead, toggle to 'Select a folder'.",
            label: "#{'folder'.labelize} ID",
            optional: false
          }
        },
        {
          name: "parent",
          label: "Destination folder/project",
          pick_list: "folders",
          control_type: :select,
          hint: "Select a destination folder/project to copy the folder into. To use parent folder/project ID instead, toggle to 'Enter parent folder/project ID'.",
          toggle_hint: "Select a destination folder/project",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter parent folder/project ID",
            name: "parent",
            control_type: :text,
            type: "string",
            label: "Destination folder/project ID",
            hint: "Enter a parent folder/project ID. To select a folder/project instead, toggle to 'Select a folder/project'.",
            optional: false
          }
        },
        { name: "title", type: :string, hint: "Title of folder.", control_type: :text, optional: false },
        { name: "titlePrefix", type: :string, hint: "Title prefix of folder.", control_type: :text, optional: true },
        {
          name: "copyDescriptions",
          type: :string,
          label: "Copy description?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original folder's description for the copied folder. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyDescriptions",
            type: :boolean,
            control_type: :checkbox,
            label: "Copy description?",
            default: "Yes",
            render_input: :boolean_input,
            hint: "Select <b>Yes</b> to copy the original folder's description for the copied folder. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyResponsibles",
          type: :string,
          default: "Yes",
          render_input: :boolean_input,
          label: "Copy assignees?",
          hint: "Enter <b>Yes</b> to copy the original folder's assignees for the copied folder. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyResponsibles",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy assignees?",
            hint: "Select <b>Yes</b> to copy the original folder's assignees for the copied folder. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        { name: "addResponsibles", label: "Add assignees to copied tasks.", type: :array, hint: "Add assignees to copied folder.", properties: [
          { name: "id", label: "Assignee ID", hint: "User ID of user to assign copied folder to." }
        ] },
        { name: "removeResponsibles", label: "Remove assignees from copied tasks", type: :array, hint: "Assignees of copied folder.", properties: [
          { name: "id", label: "User ID", hint: "User ID of user to remove from assignment of copied folder." }
        ] },
        {
          name: "copyCustomFields",
          type: :string,
          label: "Copy custom fields?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original folder's custom fields for the copied folder. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyCustomFields",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy custom fields?",
            hint: "Select <b>Yes</b> to copy the original folder's custom fields for the copied folder. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyCustomStatuses",
          type: :string,
          label: "Copy custom statuses?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original folder's custom statuses for the copied folder. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyCustomStatuses",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy custom statuses?",
            hint: "Select <b>Yes</b> to copy the original folder's custom statuses for the copied folder. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyStatuses",
          type: :string,
          label: "Copy statuses?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original folder's statuses for the copied folder. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyStatuses",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy statuses?",
            hint: "Select <b>Yes</b> to copy the original folder's statuses for the copied folder. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyParents",
          type: :string,
          label: "Copy parent folders/projects?",
          default: "No",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original folder's parent folders/projects for the copied folder. Defaults to <b>No</b>. To instead directly choose" \
          " between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyParents",
            type: :boolean,
            control_type: :checkbox,
            default: "No",
            render_input: :boolean_input,
            label: "Copy parent folders/projects?",
            hint: "Select <b>Yes</b> to copy the original folder's parent folders/projects for the copied folder. Defaults to <b>No</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        { name: "rescheduleDate", type: :date, render_input: :date_input, hint: "Copy rescheduling dates to copied tasks." },
        { name: "rescheduleMode",
          type: :string,
          control_type: "select", pick_list: [["Start", "Start"], ["End", "End"]],
          hint: "Valid only if reschedule date is present." },
        { name: "entryLimit", type: :integer, hint: "Limit maximum allowed number for tasks/folders/projects in tree for copy. Valid range: 1-100. 100 by default." },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: -> {},

      execute: ->(connection, input) {
        updated_input = input.except("id", "account_id", "field_list")
        %w[copyDescriptions copyResponsibles copyCustomFields copyCustomStatuses copyStatuses copyParents].each { |f| updated_input[f] = input[f].is_true? }
        call(:format_input, updated_input, %w[addResponsibles removeResponsibles])
        payload = call(:payload_input, updated_input)
        folder = post(call(:base_uri, connection) + "/copy_folder/#{input.delete('id')}")
                   .payload(payload)
                   .request_format_www_form_urlencoded
                   .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                     error("#{message}: #{body}")
                   end&.[]("data")&.first
        folder["description"] = folder["description"].strip_tags if folder["description"].present?
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'folder'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
            "childIds", "superParentIds", "scope", "hasAttachments", "permalink", "workflowId", "metadata", "project"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        params = { descendants: false }
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        folder = folder_id.present? ? get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : nil
        if folder.present?
          folder["description"] = folder["description"].strip_tags if folder["description"].present?
          call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
          call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
          call(:format_custom_output, folder)
        end
      }
    },

    copy_project: {
      description: "Copy <span class='provider'>project</span> in <span class='provider'>Wrike</span>",
      help: "Copies an existing project within a specified folder/project. You can also add users to share the project with.",

      config_fields: [
        {
          name: "id",
          label: "#{'project'.labelize} to be copied",
          pick_list: "folders",
          control_type: :select,
          hint: "Select a project to be copied. To use the project's ID instead, toggle to 'Enter a project ID'.",
          toggle_hint: "Select a project",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter a project ID",
            name: "id",
            control_type: :text,
            type: "string",
            hint: "Enter a project's ID. To select a project instead, toggle to 'Select a project'.",
            label: "#{'project'.labelize} ID",
            optional: false
          }
        },
        {
          name: "parent",
          label: "Destination folder/project",
          pick_list: "folders",
          control_type: :select,
          hint: "Select a destination folder/project to copy the project into. To use parent folder/project ID instead, toggle to 'Enter parent folder/project ID'.",
          toggle_hint: "Select a destination folder/project",
          optional: false,
          toggle_field: {
            toggle_hint: "Enter parent folder/project ID",
            name: "parent",
            control_type: :text,
            type: "string",
            label: "Destination folder/project ID",
            hint: "Enter a parent folder/project ID. To select a folder/project instead, toggle to 'Select a folder/project'.",
            optional: false
          }
        },
        { name: "title", type: :string, hint: "Title of project.", control_type: :text, optional: false },
        { name: "titlePrefix", type: :string, hint: "Title prefix of project.", control_type: :text, optional: true },
        {
          name: "copyDescriptions",
          type: :string,
          label: "Copy description?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original project's description for the copied project. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyDescriptions",
            type: :boolean,
            control_type: :checkbox,
            label: "Copy description?",
            default: "Yes",
            render_input: :boolean_input,
            hint: "Select <b>Yes</b> to copy the original project's description for the copied project. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyResponsibles",
          type: :string,
          default: "Yes",
          render_input: :boolean_input,
          label: "Copy assignees?",
          hint: "Enter <b>Yes</b> to copy the original project's assignees for the copied project. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyResponsibles",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy assignees?",
            hint: "Select <b>Yes</b> to copy the original project's assignees for the copied project. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        { name: "addResponsibles", label: "Add assignees to copied tasks.", type: :array, hint: "Add assignees to copied project.", properties: [
          { name: "id", label: "Assignee ID", hint: "User ID of user to assign copied project to." }
        ] },
        { name: "removeResponsibles", label: "Remove assignees from copied tasks", type: :array, hint: "Assignees of copied project.", properties: [
          { name: "id", label: "User ID", hint: "User ID of user to remove from assignment of copied project." }
        ] },
        {
          name: "copyCustomFields",
          type: :string,
          label: "Copy custom fields?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original project's custom fields for the copied project. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyCustomFields",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy custom fields?",
            hint: "Select <b>Yes</b> to copy the original project's custom fields for the copied project. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyCustomStatuses",
          type: :string,
          label: "Copy custom statuses?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original project's custom statuses for the copied project. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyCustomStatuses",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy custom statuses?",
            hint: "Select <b>Yes</b> to copy the original project's custom statuses for the copied project. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyStatuses",
          type: :string,
          label: "Copy statuses?",
          default: "Yes",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original project's statuses for the copied project. Defaults to <b>Yes</b>. To instead directly choose " \
          "between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyStatuses",
            type: :boolean,
            control_type: :checkbox,
            default: "Yes",
            render_input: :boolean_input,
            label: "Copy statuses?",
            hint: "Select <b>Yes</b> to copy the original project's statuses for the copied project. Defaults to <b>Yes</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        {
          name: "copyParents",
          type: :string,
          label: "Copy parent folders/projects?",
          default: "No",
          render_input: :boolean_input,
          hint: "Enter <b>Yes</b> to copy the original project's parent folders/projects for the copied project. Defaults to <b>No</b>. To instead directly choose" \
          " between <b>Yes</b> and <b>No</b>, toggle to 'Select'.",
          toggle_hint: "Enter",
          toggle_field: {
            name: "copyParents",
            type: :boolean,
            control_type: :checkbox,
            default: "No",
            render_input: :boolean_input,
            label: "Copy parent folders/projects?",
            hint: "Select <b>Yes</b> to copy the original project's parent folders/projects for the copied project. Defaults to <b>No</b>. To instead type " \
            "either <b>Yes</b> or <b>No</b>, toggle to 'Enter'.",
            toggle_hint: "Select"
          }
        },
        { name: "rescheduleDate", type: :date, render_input: :date_input, hint: "Copy rescheduling dates to copied tasks." },
        { name: "rescheduleMode",
          type: :string,
          control_type: "select", pick_list: [["Start", "Start"], ["End", "End"]],
          hint: "Valid only if reschedule date is present." },
        { name: "entryLimit", type: :integer, hint: "Limit maximum allowed number for tasks/folders/projects in tree for copy. Valid range: 1-100. 100 by default." },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        }
      ],

      input_fields: -> {},

      execute: ->(connection, input) {
        updated_input = input.except("id", "account_id", "field_list")
        %w[copyDescriptions copyResponsibles copyCustomFields copyCustomStatuses copyStatuses copyParents].each { |f| updated_input[f] = input[f].is_true? }
        call(:format_input, updated_input, %w[addResponsibles removeResponsibles])
        payload = call(:payload_input, updated_input)
        folder = post(call(:base_uri, connection) + "/copy_folder/#{input.delete('id')}")
                   .payload(payload)
                   .request_format_www_form_urlencoded
                   .headers(content_type: nil).after_error_response(400) do |_, body, _, message|
                     error("#{message}: #{body}")
                   end&.[]("data")&.first
        folder["description"] = folder["description"].strip_tags if folder["description"].present?
        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        call(:format_custom_output, folder)
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'project'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
            "childIds", "superParentIds", "scope", "hasAttachments", "permalink", "workflowId", "metadata", "project"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection) {
        params = { descendants: true }
        params["project"] = true
        folder_id = get(call(:base_uri, connection) + "/folders").params(params)&.[]("data")&.last&.[]("id")
        folder = folder_id.present? ? get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first : nil
        if folder.present?
          folder["description"] = folder["description"].strip_tags if folder["description"].present?
          call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds])
          call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
          call(:format_custom_output, folder)
        end
      }
    }
  },

  triggers: {
    new_or_updated_task: {
      description: 'New/updated <span class="provider">task</span> in <span class="provider">Wrike</span>',
      deprecated: true,

      type: :paging_desc,

      input_fields: ->(_) {
        [
          {
            name: "since",
            type: :timestamp,
            label: "From",
            sticky: true,
            hint: "Get tasks created or updated since given date/time. Leave empty to get tasks created or updated from one hour ago."
          }
        ]
      },

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "sortField" => "UpdatedDate",
          "sortOrder" => "Desc"
        }
        response = get(call(:base_uri, connection) + "/tasks", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end

        next_updated_since = response["data"].last["updatedDate"] if response["data"].present?
        {
          events: response["data"],
          next_page: response["data"].length > 100 ? next_updated_since : nil
        }
      },

      document_id: ->(task) {
        task["id"]
      },

      sort_by: ->(task) {
        task["updatedDate"]
      },

      output_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "id", "accountId", "title", "status", "importance", "createdDate", "updatedDate", "scope", "dates", "customStatusId", "permalink", "priority", "project"
        )
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/tasks?limit=1&sortField=UpdatedDate&sortOrder=Desc")&.[]("data")&.last || {}
      }
    },

    new_comment: {
      description: 'New <span class="provider">comment</span> in <span class="provider">Wrike</span>',
      deprecated: true,

      type: :paging_desc,

      input_fields: -> {
        [
          { name: "since", type: :date_time, label: "From", sticky: true, hint: "Get comments created since given date/time. Leave empty to get comments created one hour ago" }
        ]
      },

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "plainText" => true
        }

        response = get(call(:base_uri, connection) + "/comments", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end
        next_updated_since = response["data"].last["updatedDate"] if response["data"].present?
        next_updated_since ||= (since.to_time + 7.days).to_time.utc.iso8601 if since < 7.days.ago
        {
          events: response["data"],
          next_page: response["data"].length > 100 ? next_updated_since : nil
        }
      },

      dedup: ->(comment) {
        comment["id"]
      },

      output_fields: ->(object_definitions) {
        object_definitions["comment"].ignored("plainText")
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/comments?limit=1")&.[]("data")&.first || {}
      }
    },

    new_or_updated_folder: {
      description: 'New/updated <span class="provider">folder</span> in <span class="provider">Wrike</span>',
      help: "Use get folder by ID action in corresponding steps to get more information about the folder",
      deprecated: true,

      type: :paging_desc,

      input_fields: -> {
        [
          {
            name: "since",
            type: :timestamp,
            label: "From",
            sticky: true,
            hint: "Get folders created or updated since given date/time. Leave empty to get folders created or updated one hour ago"
          },
          {
            name: "strip_tags",
            label: "Convert to plaintext?",
            control_type: "checkbox",
            type: "boolean",
            default: true,
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Select from options list",
            hint: "Select <b>Yes</b> to convert description to plain text.",
            toggle_field: {
              name: "strip_tags",
              label: "Convert to plaintext?",
              type: "string",
              control_type: "text",
              optional: true,
              render_input: "boolean_conversion",
              toggle_hint: "Provide custom value",
              hint: "Allowed values are <b>true</b>, <b>false</b>."
            }
          }
        ]
      },

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}"
        }
        response = get(call(:base_uri, connection) + "/folders", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end
        response["data"] = response["data"].sort_by do |data|
          data["updatedDate"]
        end
        response["data"].each do |data|
          call(:strip_html_tags, data, input["strip_tags"], true)
          call(:format_output, data, %w[sharedIds parentIds childIds])
          call(:format_output, data["project"], %w[ownerIds]) if data["project"].present?
        end
        next_updated_since = response["data"].last["updatedDate"] if response["data"].present?
        {
          events: response["data"].reverse,
          next_page: response["data"].length > 100 ? next_updated_since : nil
        }
      },

      document_id: ->(folder) {
        folder["id"]
      },

      sort_by: ->(folder) {
        folder["updatedDate"]
      },

      output_fields: ->(object_definitions) {
        object_definitions["folder"].only(
          "id", "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
          "childIds", "scope", "permalink", "workflowId", "project"
        )
      },

      sample_output: ->(connection, input) {
        folder_id = get(call(:base_uri, connection) + "/folders")&.[]("data")&.last&.[]("id")
        permalink = get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first&.[]("permalink")
        folder = get(call(:base_uri, connection) + "/folders?permalink=#{permalink}")&.[]("data")&.first || {}
        call(:strip_html_tags, folder, input["strip_tags"], default: false)
        call(:format_output, folder, %w[sharedIds parentIds childIds])
        call(:format_output, folder["project"], %w[ownerIds]) if folder["project"].present?
        folder
      }
    },

    new_or_updated_task_v2: {
      description: 'New/updated <span class="provider">task</span> in <span class="provider">Wrike</span>',
      title: "New/updated task",

      config_fields: [
        {
          name: "folder_id",
          type: "string",
          label: "Folder name",
          pick_list: "folders",
          control_type: :select,
          hint: "Select a folder to get the task from",
          optional: true
        },
        {
          name: "custom_status",
          control_type: :multiselect,
          pick_list: :custom_statuses,
          sticky: true,
          label: "Custom statuses",
          hint: "Returns tasks that match any chosen custom statuses."
        },
        { name: "task_status",
          control_type: "select",
          pick_list: "task_status",
          hint: "Trigger will pick up only new/updated tasks with this status." },
        {
          name: "since",
          type: :timestamp,
          label: "From",
          sticky: true,
          hint: "Get tasks created or updated since given date/time. Leave empty to get tasks created or updated one hour ago."
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: false,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      poll: ->(connection, input, next_poll) {
        since = (next_poll&.[](:updated_date).presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "sortField" => "UpdatedDate",
          "sortOrder" => "Asc",
          "pageSize" => 100,
          "nextPageToken" => next_poll&.[](:nextPageToken),
          "status" => input["task_status"],
          "customStatuses" => input["custom_status"],
          "fields" => '["recurrent","description","briefDescription","parentIds","superParentIds","sharedIds","responsibleIds","authorIds",' \
                      '"hasAttachments","attachmentCount","superTaskIds","subTaskIds","dependencyIds","metadata","customFields"]'
        }.compact
        response = get(call(:base_uri, connection) + "#{input['folder_id'].present? ? '/folders/' + input['folder_id'] : ''}/tasks", params)
                     .after_error_response(400) do |_, body, _, message|
                       if body =~ /Parameter 'nextPageToken' value is invalid/
                         { "data" => [] }
                       else
                         error("#{message}: #{body}")
                       end
                     end

        response["data"].each do |data|
          call(:format_response, data, connection)
          call(:strip_html_tags, data, input["strip_tags"], false)
        end
        next_updated_since = response["data"].present? ? response["data"].last["updatedDate"] : since

        {
          events: response["data"],
          next_poll: { nextPageToken: response["nextPageToken"], updated_date: next_updated_since },
          can_poll_more: response["nextPageToken"].present?
        }
      },

      dedup: ->(task) {
        "#{task['id']}@#{task['updatedDate']}"
      },

      output_fields: ->(object_definitions) {
        object_definitions["task"].only(
          "id", "accountId", "title", "status", "importance", "createdDate", "updatedDate",
          "scope", "dates", "customStatusId", "custom_status", "permalink", "priority", "project", "description",
          "briefDescription", "parentIds", "superParentIds", "sharedIds", "responsibleIds",
          "authorIds", "hasAttachments", "attachmentCount", "superTaskIds", "subTaskIds",
          "dependencyIds", "metadata"
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection, input) {
        fields = '["recurrent","description","briefDescription","parentIds","superParentIds","sharedIds","responsibleIds","authorIds",' \
                 '"hasAttachments","attachmentCount","superTaskIds","subTaskIds","dependencyIds","metadata","customFields"]'
        response = get(call(:base_uri, connection) + "/tasks?fields=#{fields}&limit=1&sortField=UpdatedDate&sortOrder=Desc")&.[]("data")&.last
        if response.present?
          call(:format_output, response, %w[parentIds superParentIds sharedIds responsibleIds authorIds followerIds superTaskIds subTaskIds dependencyIds])
          call(:strip_html_tags, response, input["strip_tags"], true)
          if response["customStatusId"].present?
            cs = call(:get_custom_statuses, connection, false)[response["customStatusId"]]
            response["custom_status"] = { name: "#{cs['wf_name']}|#{cs['name']}", id: response["customStatusId"] }
          end
          call(:format_custom_output, response)
        else
          {}
        end
      }
    },

    new_comment_v2: {
      title: "New comment",
      description: 'New <span class="provider">comment</span> in <span class="provider">Wrike</span>',
      help: "Retrieves up to 7 days of new comments for each poll. " \
      "If the last new comment event is older than 7 days, more than 1 poll will be required to retrieve new comments " \
      "up to current date & time. To manually retrieve new comments, go to the jobs tab and click 'Check now'.",

      input_fields: -> {
        [
          { name: "since", type: :date_time, label: "From", sticky: true, hint: "Get comments created since given date/time. Leave empty to get comments created one hour ago." }
        ]
      },

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "plainText" => true,
          "limit" => 100
        }.compact
        response = get(call(:base_uri, connection) + "/comments", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end

        next_updated_since = if response["data"].last.present? && since.to_time.utc != response["data"].last["updatedDate"].to_time.utc
                               response["data"].last["updatedDate"]
                             elsif since < 7.days.ago
                               (since.to_time.utc + 7.days).iso8601
                             else
                               since
                             end
        {
          events: response["data"].reverse,
          next_poll: next_updated_since,
          can_poll_more: response["data"].length >= 100
        }
      },

      dedup: ->(comment) {
        comment["id"]
      },

      output_fields: ->(object_definitions) {
        object_definitions["comment"].ignored("plainText")
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/comments?limit=1")&.[]("data")&.first || {}
      }
    },

    new_or_updated_timelog: {
      description: 'New/updated <span class="provider">timelog</span> in <span class="provider">Wrike</span>',
      title: "New/updated timelog",
      help: "Fetches new/updated timelog events.",

      input_fields: -> {
        [
          {
            name: "since",
            type: :timestamp,
            label: "From",
            sticky: true,
            hint: <<-HINT
              When you start recipe for the first time, it picks up trigger events from this specified date and time.
              Leave empty to get events created or updated one hour ago.
            HINT
          }
        ]
      },

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "plainText" => true
        }

        response = get(call(:base_uri, connection) + "/timelogs", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end

        response["data"] = response["data"].sort_by do |data|
          data["updatedDate"]
        end

        next_updated_since = response["data"].last["updatedDate"] if response["data"].present?
        {
          events: response["data"],
          next_poll: next_updated_since,
          can_poll_more: false
        }
      },

      dedup: ->(timelog) {
        "#{timelog['id']}@#{timelog['updatedDate']}"
      },

      output_fields: ->(object_definitions) {
        object_definitions["timelog"]
      },

      sample_output: ->(connection) {
        get(call(:base_uri, connection) + "/timelogs")["data"]&.last || {}
      }
    },

    new_or_updated_folder_v2: {
      title: "New/updated folder",
      description: "New/updated <span class='provider'>folder</span> in <span class='provider'>Wrike</span>",
      help: "Returns folder tree data of new/updated folder. To get more information about the folder, use <b>Get folder by ID</b> action in corresponding steps.",
      business_object: "folder",

      config_fields: [
        {
          name: "since",
          type: :timestamp,
          label: "From",
          sticky: true,
          hint: <<-HINT
            When you start recipe for the first time, it picks up trigger events from this specified date and time.
            Leave empty to get events created or updated one hour ago.
          HINT
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: false,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "fields" => '["metadata","hasAttachments","attachmentCount","description","briefDescription","customFields","customColumnIds","superParentIds"]'
        }.compact
        response = get(call(:base_uri, connection) + "/folders", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end

        custom_statuses = call(:get_custom_statuses, connection, false)

        response["data"] = response["data"].sort_by do |data|
          data["updatedDate"]
        end
        response["data"].each do |data|
          call(:format_output, data, %w[sharedIds parentIds childIds superParentIds customColumnIds])
          if data["project"].present?
            call(:format_output, data["project"], %w[ownerIds])
            if data["project"]["customStatusId"].present?
              cs = custom_statuses[data["project"]["customStatusId"]]
              if cs.blank?
                custom_statuses = call(:get_custom_statuses, connection, true)
                cs = custom_statuses[data["project"]["customStatusId"]]
              end
              data["custom_status"] =
                { name: [cs&.[]("wf_name"), cs&.[]("name")]&.join("|") == "|" ? nil : [cs&.[]("wf_name"), cs&.[]("name")]&.join("|"), id: data["project"]["customStatusId"] }
            end
          end
          call(:format_custom_output, data)
          call(:strip_html_tags, data, input["strip_tags"], false)
        end

        next_updated_since = response["data"].last["updatedDate"] if response["data"].present?
        {
          events: response["data"],
          next_poll: next_updated_since,
          can_poll_more: false
        }
      },

      dedup: ->(folder) {
        "#{folder['id']}@#{folder['updatedDate']}"
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'folder'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
            "briefDescription", "metadata", "hasAttachments", "attachmentCount", "superParentIds", "customColumnIds",
            "childIds", "scope", "permalink", "workflowId", "project", "custom_status"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection, input) {
        folder_id = get(call(:base_uri, connection) + "/folders?")&.[]("data")&.last&.[]("id")
        permalink = get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first&.[]("permalink")
        fields = '["metadata","hasAttachments","attachmentCount","description","briefDescription","customFields","customColumnIds","superParentIds"]'
        folder = get(call(:base_uri, connection) + "/folders?permalink=#{permalink}&fields=#{fields}")&.[]("data")&.first || {}

        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds customColumnIds])
        if folder["project"].present?
          call(:format_output, folder["project"], %w[ownerIds])
          if folder["project"]["customStatusId"].present?
            cs = call(:get_custom_statuses, connection, false)[folder["project"]["customStatusId"]]
            folder["custom_status"] =
              { name: [cs&.[]("wf_name"), cs&.[]("name")]&.join("|") == "|" ? nil : [cs&.[]("wf_name"), cs&.[]("name")]&.join("|"), id: folder["project"]["customStatusId"] }
          end
        end
        call(:format_custom_output, folder)
        call(:strip_html_tags, folder, input["strip_tags"], false)
        folder
      }
    },

    new_or_updated_project_v2: {
      title: "New/updated project",
      description: "New/updated <span class='provider'>project</span> in <span class='provider'>Wrike</span>",
      help: "Fetches new/updated project events.",
      business_object: "project",

      config_fields: [
        {
          name: "since",
          type: :timestamp,
          label: "From",
          sticky: true,
          hint: <<-HINT
            When you start recipe for the first time, it picks up trigger events from this specified date and time.
            Leave empty to get events created or updated one hour ago.
          HINT
        },
        {
          name: "field_list",
          control_type: :multiselect,
          hint: "Select the custom fields to be returned in the output datatree. If left blank, all custom fields will be retrieved.",
          pick_list: "custom_fields",
          label: "Custom fields",
          optional: true,
          sticky: true,
          delimiter: "\n"
        },
        {
          name: "strip_tags",
          label: "Convert to plaintext?",
          control_type: "checkbox",
          type: "boolean",
          default: false,
          optional: true,
          render_input: "boolean_conversion",
          toggle_hint: "Select from options list",
          hint: "Select <b>Yes</b> to convert description to plain text.",
          toggle_field: {
            name: "strip_tags",
            label: "Convert to plaintext?",
            type: "string",
            control_type: "text",
            optional: true,
            render_input: "boolean_conversion",
            toggle_hint: "Provide custom value",
            hint: "Allowed values are <b>true</b>, <b>false</b>."
          }
        }
      ],

      poll: ->(connection, input, updated_date) {
        since = (updated_date.presence || input["since"].presence || 1.hour.ago).to_time.utc.iso8601
        params = {
          "updatedDate" => "{'start':'#{since}'}",
          "fields" => '["metadata","hasAttachments","attachmentCount","description","briefDescription","customFields","customColumnIds","superParentIds"]'
        }.compact
        params["project"] = true
        response = get(call(:base_uri, connection) + "/folders", params).after_error_response(400) do |_, body, _, message|
          error("#{message}: #{body}")
        end

        custom_statuses = call(:get_custom_statuses, connection, false)

        response["data"] = response["data"].sort_by do |data|
          data["updatedDate"]
        end
        response["data"].each do |data|
          call(:format_output, data, %w[sharedIds parentIds childIds superParentIds customColumnIds])
          if data["project"].present?
            call(:format_output, data["project"], %w[ownerIds])
            if data["project"]["customStatusId"].present?
              cs = custom_statuses[data["project"]["customStatusId"]]
              if cs.blank?
                custom_statuses = call(:get_custom_statuses, connection, true)
                cs = custom_statuses[data["project"]["customStatusId"]]
              end
              data["custom_status"] =
                { name: [cs&.[]("wf_name"), cs&.[]("name")]&.join("|") == "|" ? nil : [cs&.[]("wf_name"), cs&.[]("name")]&.join("|"), id: data["project"]["customStatusId"] }
            end
          end
          call(:format_custom_output, data)
          call(:strip_html_tags, data, input["strip_tags"], false)
        end

        next_updated_since = response["data"].last["updatedDate"] if response["data"].present?
        {
          events: response["data"],
          next_poll: next_updated_since,
          can_poll_more: false
        }
      },

      dedup: ->(folder) {
        "#{folder['id']}@#{folder['updatedDate']}"
      },

      output_fields: ->(object_definitions) {
        [
          { name: "id", label: "#{'project'.labelize} ID" }
        ].concat(
          object_definitions["folder"].only(
            "accountId", "title", "createdDate", "updatedDate", "description", "sharedIds", "parentIds",
            "briefDescription", "metadata", "hasAttachments", "attachmentCount", "superParentIds", "customColumnIds",
            "childIds", "scope", "permalink", "workflowId", "project", "custom_status"
          )
        ).concat(object_definitions["custom"])
      },

      sample_output: ->(connection, input) {
        folder_id = get(call(:base_uri, connection) + "/folders?project=true")&.[]("data")&.last&.[]("id")
        permalink = get(call(:base_uri, connection) + "/folders/#{folder_id}")&.[]("data")&.first&.[]("permalink")
        fields = '["metadata","hasAttachments","attachmentCount","description","briefDescription","customFields","customColumnIds","superParentIds"]'
        folder = get(call(:base_uri, connection) + "/folders?permalink=#{permalink}&fields=#{fields}")&.[]("data")&.first || {}

        call(:format_output, folder, %w[sharedIds parentIds childIds superParentIds customColumnIds])
        if folder["project"].present?
          call(:format_output, folder["project"], %w[ownerIds])
          if folder["project"]["customStatusId"].present?
            cs = call(:get_custom_statuses, connection, false)[folder["project"]["customStatusId"]]
            folder["custom_status"] =
              { name: [cs&.[]("wf_name"), cs&.[]("name")]&.join("|") == "|" ? nil : [cs&.[]("wf_name"), cs&.[]("name")]&.join("|"), id: folder["project"]["customStatusId"] }
          end
        end
        call(:format_custom_output, folder)
        call(:strip_html_tags, folder, input["strip_tags"], false)
        folder
      }
    }
  },

  pick_lists: {
    accounts: ->(connection) {
      accounts = get(call(:base_uri, connection) + "/account")&.[]("data")
      accounts.present? ? accounts.map { |account| [account["name"], account["id"]] } : []
    },

    task_status: -> {
      %w[Active Completed Deferred Cancelled].map { |s| [s, s] }
    },

    custom_fields: ->(connection) {
      get(call(:base_uri, connection) + "/customfields")&.[]("data")&.map do |f|
        [f["title"], "#{f['title']}___#{f['id']}___#{f['type']}"]
      end || []
    },

    custom_statuses: ->(connection) {
      cs = call(:get_custom_statuses, connection, true)
      if cs.present?
        cs.map do |k, v|
          ["#{v[:wf_name]}|#{v[:name]}", k]
        end
      end || []
    },

    folders: ->(connection) {
      folders = get(call(:base_uri, connection) + "/folders")&.[]("data")
      folders.present? ? folders.map { |f| [f["title"], f["id"]] } : []
    },

    timelog_categories: ->(connection) {
      timelog_categories = get(call(:base_uri, connection) + "/timelog_categories")&.[]("data")
      timelog_categories.present? ? timelog_categories.map { |f| [f["name"], f["id"]] } : []
    }
  }
}

descriptor