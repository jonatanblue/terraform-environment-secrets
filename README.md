# Environment specific secrets in Terraform

If you have more than one environment (here we have **dev** and **prod**), and you need to pass in *secret* variables that are *different* between environments, Terraform is particularly difficult.

## Problem

**You cannot use interpolation in a variable definition.**

If you for example attempt to use your deployment environment to look up the correct password, you could attempt to do something like this in your `variables.tf` file:

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

## Workaround: shell script wrapper

You can work around this problem by keeping track of the deployment environment outside of Terraform, by using a shell script to export the right variables before running Terraform.

    if [[ "${deployment_environment}" == "dev" ]]
    then
      export TF_VAR_DATABASE_PASSWORD="${DATABASE_PASSWORD_DEV}"
    elif [[ "${deployment_environment}" == "prod" ]]
    then
      export TF_VAR_DATABASE_PASSWORD="${DATABASE_PASSWORD_PROD}"
    fi
    ...
    terraform plan -var-file=${deployment_environment}.tfvars

And so on.

This requires you to maintain and run that shell script wrapper as part of running Terraform, which may or may not be acceptable for your use case.

## Workaround: null_data_source

We can use the `null_data_source` to achieve what effectively is variable interpolation.

Here's the code:

    variable "env" {}
    variable "PASSWORD_DEV" {}
    variable "PASSWORD_PROD" {}

    data "null_data_source" "environment_specific_password" {
      inputs = {
        dev = "${var.PASSWORD_DEV}"
        prod = "${var.PASSWORD_PROD}"
      }
    }

    data "template_file" "test" {
      template = "in env ${var.env} the environment specific password is ${lookup(data.null_data_source.environment_specific_password.inputs, var.env)}"
    }

    output "template" {
      value = "${data.template_file.test.rendered}"
    }

Now all we need to do is set the passwords as environment variables and tell Terraform which environment we want to deploy to.

    export PASSWORD_DEV="apples"
    export PASSWORD_PROD="pears"

    # Deploy to dev
    terraform apply -var "env=dev"

    # Deploy to prod
    terraform apply -var "env=prod"

# Credits

Thanks to @dennybaa for providing a [guiding example](https://github.com/hashicorp/terraform/issues/4084#issuecomment-236429459).

