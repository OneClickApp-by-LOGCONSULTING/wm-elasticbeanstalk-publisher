# REUSABLE ACTION - Build and Deploy a WAVEMAKER application to AWS Elastic Beanstalk

This GitHub Action is designed to build and deploy a WAVEMAKER application to AWS Elastic Beanstalk. The pipeline automates the process of building the WAVEMAKER application, uploading the WAR file to AWS S3, and deploying it to a specified Elastic Beanstalk environment.

## Workflow

### Trigger
This action is configured to be called from another workflow (`workflow_call`), meaning it can be reused in different contexts.

### Inputs
The action accepts the following input parameters:

- **node-version** (optional): The version of Node.js to use, default is `18.16.1`.
- **maven-version** (optional): The version of Maven to use, default is `3.9.9`.
- **java-version** (optional): The version of Java to use for building the application, default is `21`.
- **aws-region** (optional): The AWS region to use, default is `eu-south-1`.
- **environment-name** (required): The name of the Elastic Beanstalk environment to deploy the application.
- **wm-app-name** (optional): The name of the WAVEMAKER application, default is `OneClickApp`.
- **beanstalk-application-name** (optional): The name of the AWS Elastic Beanstalk application, default is `OneClickApp`.
- **wm-profile** (required): The WAVEMAKER configuration profile (e.g., `prod`).
- **aws-s3-bucket-name** (required): The name of the S3 bucket to upload the WAR file.
- **aws-s3-bucket-region** (required): The AWS region of the S3 bucket, default is `eu-south-1`.

### Secrets
The action requires the following secrets to interact with AWS:

- **aws-access-key-id**: The AWS Access Key ID.
- **aws-secret-access-key**: The AWS Secret Access Key.

### Job Steps

1. **Checkout the repository**:
   The repository code is cloned to the GitHub runner.

2. **Verify the WAVEMAKER configuration file**:
   The action checks the properties file to ensure it doesn't contain references to `wavemakeronline.com` to avoid accidental deployment to production.

3. **Setup Node.js and Maven**:
   The action configures Node.js (using the specified or default version) and Maven, including caching Maven dependencies for improved build performance on subsequent runs.

4. **Check version environments**:
   The action prints the versions of Git, Maven, NPM, and Node.js to verify the build environment.

5. **Build the WAR file**:
   The `mvn clean install` command is executed to build the WAVEMAKER application using the specified profile.

6. **Download a sample WAR file**:
   A sample WAR file (`ROOT.war`) is downloaded from Tomcat for demonstration purposes.

7. **Configure AWS credentials**:
   The action configures AWS credentials using the provided access keys via secrets.

8. **Upload to S3 and deploy to Elastic Beanstalk**:
   - The resulting WAR file (built via Maven) is uploaded to an S3 bucket.
   - A new Elastic Beanstalk application version is created using the uploaded WAR file, and the environment is updated with this version.

### Execution and Output

- The action logs various status messages throughout the process, providing feedback on the creation, upload, and deployment of the application.
- The WAR file is zipped before being uploaded to S3 and deployed via Elastic Beanstalk.

## Important Notes
- Ensure that the AWS credentials configuration and AWS region are correctly set for the target account and environment.
- The S3 bucket name and the Elastic Beanstalk application name must be specified for the upload and deployment process to work properly.

For more details on WAVEMAKER releases, check the [WAVEMAKER Release Notes](https://docs.wavemaker.com/learn/wavemaker-release-notes/).
