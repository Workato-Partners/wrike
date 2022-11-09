# Setting up your Connector Repository
Welcome to your provisioned connector repository! This Github repository is provisioned for your connector and will contain all related assets including important partnership details, your connector code and related unit tests.

This repository requires that you use [Workato CLI](https://docs.workato.com/developing-connectors/sdk/cli.html#sdk-cli) to develop the connector and its related tests. We advise you to read through the CLI documentation to understand how to use Workato's ruby libraries to develop and test locally. 

## Pre-requisites
1. You have an understanding of the Workato Connector SDK and SDK CLI
2. You have received your master.key file from the Workato team. **IMPORTANT** This key is also stored as a secret in your Github repository for running rSpec tests. Do not share this key with anyone outside of your team

## Getting started
Use the [Connector SDK CLI](https://docs.workato.com/developing-connectors/sdk/cli.html) to run your connector code. It's a Ruby software package that emulates how Workato would parse and execute your connector code. Below, we go through some basic examples but full guides and details can be found in our documentation.

## Provide connection settings for local testing
Connection settings consists of sensitive information like passwords or other secrets. That's why connection settings are stored in an encrypted fil, e.g. `settings.yaml.enc`. You will need to have the secret key passed to you by the Workato team stored as `master.key` in your local project directory.

Alternatively, run this command on terminal to create or update connection settings file:

```bash
EDITOR="nano" workato edit settings.yaml.enc
```

This is an example settings file (YAML format):

```yaml
username: test_un
password: test_pw
```

## Running connector code locally
In the below example, we are going to use the `app_name` connector as an example and execute the `test` block and action block `get_user`.

To run the execute portion of the `test` code from the connector folder:

```bash
workato exec test
```

Refer to [Connector SDK CLI Documentation](https://docs.workato.com/developing-connectors/sdk/cli/guides/getting-started.html) to learn about using the `workato` CLI.

## Code styling and formatting

Use [RuboCop](https://rubocop.org/) to check your code style (linting) and to format your code based on the community-driven [Ruby Style Guide](https://rubystyle.guide/).

In case of using the pre-configured Visual Studio Code development environment, RuboCop will be executes automatically and warnings will be shown in the Visual Studio Code user interface.
    
![problems-view](.devcontainer/problems-view.png)

Otherwise, you can run `rubocop` manually with no arguments to check all Ruby source files in the current folder and subfolders:

```bash
$ rubocop
```

Alternatively you can pass `rubocop` a list of files and folders to check:

```bash
$ rubocop connector.rb
```

Refer to [RuboCop Documentation](https://docs.rubocop.org/rubocop/1.12/usage/basic_usage.html) to learn about using the `rubocop` CLI.

## Writing unit tests

Use [RSpec](https://rspec.info/) to develop behaviour driven unit tests.

Place unit test files (aka spec-files) files in the `spec` folder of your connector folder and make sure the filenames end with `_spec.rb`. Refer to [Workato How-to Guide](https://docs.workato.com/developing-connectors/sdk/cli/guides/rspec/writing_tests.html) to learn more about writing tests for any lambda in your connector.

In case of using the pre-configured Visual Studio Code development environment, RSpec unit tests will be shown in the Test Explorer:

![text-explorer](.devcontainer/test-explorer.png)

Otherwise, you can run RSpec unit tests manually. Running `rspec .` from root of the repository will run all RSpec tests for all connectors:

```bash
$ rspec .
```

Alternatively you can pass `rspec` a list of files and directories to check. E.g. to run the tests for the `app_name` connector:

```bash
$ rspec spec/connector_spec.rb
```

Refer to [RSpec Documentation](https://rspec.info/documentation/3.10/rspec-core/#basic-structure) to learn about creating unit tests and using the `rspec` CLI.

## Generate output json files

Generate unit test files by running _Tasks: Run Tasks_ command from the [Command Palette](https://code.visualstudio.com/docs/getstarted/userinterface#_command-palette) and selecting _Generate output json files_.

Alternatively, run this command on terminal to generate unit test files:

    ```bash
    ./automate app_name generate_output
    ```

Follow the prompt on the terminal to generate the output json file for each action in the correct folder directory.

**Important: Provide the required input json files in the input folder before running this task.**

This is an example of the prompt sequence for generating output json files for an action:

```bash
"Enter the attribute name you want to generate for:" action
"Enter the action name:" get_record
"Are there multiple objects? (Y/N):" y
"Enter the object name:" event
```

This results in the file get_record_event.json being created in the output/actions of the application or service directory.

## Implementing OAuth2 authorization code flow

Implement OAuth2 authorization code flow by running _Tasks: Run Tasks_ command from the [Command Palette](https://code.visualstudio.com/docs/getstarted/userinterface#_command-palette) and selecting _Implement OAuth2 authorization code flow_.

Alternatively, run this command on terminal to implement Oauth authorization code flow:

    ```bash
    ./automate app_name oauth2
    ```

Begin the OAuth2 code flow and a browser page will pop up allowing you to select the required scopes and authorize the application. The auth code is then stored in the settings.yaml.enc file. If no auth code is returned in the next 20 seconds, the process is terminated. Refer to the [documentation](https://docs.workato.com/developing-connectors/sdk/cli/guides/cli/test.html#invoking-the-test-lambda-for-oauth2-auth-code-grant-scenarios) on OAuth2 code grant for more information.

**Note: Some applications may require you to add http://localhost:45555/oauth/callback as another redirect URI for the oauth2 code flow to work.** 