data "null_data_source" "environment_specific_password" {
  inputs = {
    dev = "${var.PASSWORD_DEV}"
    prod = "${var.PASSWORD_PROD}"
  }
}

data "template_file" "test" {
  template = "in environment ${var.env} the password is ${lookup(data.null_data_source.environment_specific_password.inputs, var.env)}"
}
