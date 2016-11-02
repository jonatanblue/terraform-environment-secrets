# Environment specific secrets in Terraform

If you have more than one environment (here we have **dev** and **prod**), and you need to pass in *secret* variables that are *different* between environments, Terraform is particularly difficult.

## Problem

**You cannot use interpolation in variable definitions.**

If you for example attempt to use your deployment environment to look up the correct password, you could (wrongly) attempt to do something like this in your `variables.tf` file:

    variable "env" {}
    variable "database_password" {
      default = {
        dev = "${var.DATABASE_PASSWORD_DEV}"
        prod = "${var.DATABASE_PASSWORD_PROD}"
      }
    }

and then in your `main.tf` file look up the password using the environment (here either "dev" or "prod"):

    ...
      password = "${lookup(var.database_password, var.env)}"
    ...

which will result in this error:

    * Variable 'database_password': cannot contain interpolations

This means that either your password is hard coded 😣 (in plain text 😖) in a `.tfvars` file for each environment, or it is not environment specific (which means the same password in dev is used in prod ☹️).

## Workaround: shell script wrapper

You can work around this problem by keeping track of the deployment environment outside of Terraform, using a shell script to export the correct variables before running Terraform.

    if [[ "${deployment_environment}" == "dev" ]]
    then
      export TF_VAR_PASSWORD="${PASSWORD_DEV}"
    elif [[ "${deployment_environment}" == "prod" ]]
    then
      export TF_VAR_PASSWORD="${PASSWORD_PROD}"
    fi
    ...
    terraform plan -var-file=${deployment_environment}.tfvars

And so on.

## Workaround: null_data_source

Another approach is to use the `null_data_source` to achieve what effectively is variable interpolation.

Here's the code:

    # Pass in when running terraform
    variable "env" {}

    # These variables should obtained from the shell environment
    variable "PASSWORD_DEV" {}    # TF_VAR_PASSWORD_DEV
    variable "PASSWORD_PROD" {}   # TF_VAR_PASSWORD_PROD

    # Create a map that interpolates the secrets via environment variables
    data "null_data_source" "environment_specific_password" {
      inputs = {
        dev = "${var.PASSWORD_DEV}"
        prod = "${var.PASSWORD_PROD}"
      }
    }

    # This won't create any actual resource but demonstrates how to access the values
    data "template_file" "test" {
      template = "in env ${var.env} the environment specific password is ${lookup(data.null_data_source.environment_specific_password.inputs, var.env)}"
    }

    # This outputs a different password, depending on environment
    output "template" {
      value = "${data.template_file.test.rendered}"
    }

Now all we need to do is set the passwords as environment variables and tell Terraform which environment we want to deploy to.

    # Set passwords
    export PASSWORD_DEV="apples"
    export PASSWORD_PROD="pears"

    # Deploy to dev

    terraform apply -var "env=dev"

        data.null_data_source.environment_specific_password: Refreshing state...
        data.template_file.test: Refreshing state...

        Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

        Outputs:

        template = in environment dev the password is apples


    # Deploy to prod

    terraform apply -var "env=prod"

        data.null_data_source.environment_specific_password: Refreshing state...
        data.template_file.test: Refreshing state...

        Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

        Outputs:

        template = in environment prod the password is pears

# Credits

Thanks to

* [@DavyK](https://github.com/DavyK) for the idea
* [@dennybaa](https://github.com/@dennybaa) for providing a [guiding example](https://github.com/hashicorp/terraform/issues/4084#issuecomment-236429459).
