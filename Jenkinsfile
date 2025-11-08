pipeline {
  agent any

  environment {
    AWS_REGION    = 'ap-south-1'
    AWS_ACCOUNT_ID = '708972351530'      
    TERRAFORM_DIR = 'terraform'
    IMAGE_TAG     = 'latest'
  }

  stages {

    /* ============ 1. CHECKOUT CODE ============ */
    stage('Checkout') {
      steps {
        echo "Fetching code from GitHub repository configured in Jenkins job..."
        checkout scm
      }
    }

    /* ============ 2. TERRAFORM (IaC) ============ */
    stage('Terraform Init & Apply (Conditional)') {
      when {
        anyOf {
          changeset "terraform/**"
          expression { env.BRANCH_NAME == 'main' }
        }
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access']]) {
          dir("${TERRAFORM_DIR}") {
            sh '''
              terraform init -input=false
              terraform plan -out=tfplan -input=false
              terraform show -json tfplan > tfplan.json || true
              CHANGES=$(jq '.resource_changes | length' tfplan.json || echo "0")

              if [ "$CHANGES" -gt 0 ]; then
                echo "Terraform changes detected: $CHANGES resources. Applying..."
                terraform apply -auto-approve tfplan
              else
                echo "No Terraform changes detected. Skipping apply."
              fi
            '''
          }
        }
      }
    }

    /* ============ 3. FETCH TERRAFORM OUTPUTS ============ */
    stage('Fetch Terraform Outputs') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access']]) {
          dir("${TERRAFORM_DIR}") {
            script {
              env.EC2_IP       = sh(script: 'terraform output -raw ec2_public_ip', returnStdout: true).trim()
              env.USER_REPO    = sh(script: 'terraform output -raw user_repo_url', returnStdout: true).trim()
              env.ORDERS_REPO  = sh(script: 'terraform output -raw orders_repo_url', returnStdout: true).trim()
              env.INVENTORY_REPO = sh(script: 'terraform output -raw inventory_repo_url', returnStdout: true).trim()
              echo "EC2 Instance IP: ${env.EC2_IP}"
            }
          }
        }
      }
    }

    /* ============ 4. BUILD DOCKER IMAGES ============ */
    stage('Build Docker Images') {
      steps {
        script {
          sh "docker build -t user-service:${IMAGE_TAG} ./user-service"
          sh "docker build -t order-service:${IMAGE_TAG} ./order-service"
          sh "docker build -t inventory-service:${IMAGE_TAG} ./inventory-service"
        }
      }
    }

    /* ============ 5. PUSH IMAGES TO ECR ============ */
    stage('Push Docker Images to ECR') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-access']]) {
          script {
            sh """
              aws ecr get-login-password --region ${AWS_REGION} | \
              docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

              docker tag user-service:${IMAGE_TAG} ${USER_REPO}:${IMAGE_TAG}
              docker tag order-service:${IMAGE_TAG} ${ORDERS_REPO}:${IMAGE_TAG}
              docker tag inventory-service:${IMAGE_TAG} ${INVENTORY_REPO}:${IMAGE_TAG}

              docker push ${USER_REPO}:${IMAGE_TAG}
              docker push ${ORDERS_REPO}:${IMAGE_TAG}
              docker push ${INVENTORY_REPO}:${IMAGE_TAG}
            """
          }
        }
      }
    }

    /* ============ 6. DEPLOY TO EC2 ============ */
    stage('Deploy to EC2 Instance') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'EC2_KEY')]) {
          script {
            sh """
              # Prepare docker-compose with ECR URLs
              sed -e 's|__USER_REPO__|${USER_REPO}|g' \
                  -e 's|__ORDERS_REPO__|${ORDERS_REPO}|g' \
                  -e 's|__INVENTORY_REPO__|${INVENTORY_REPO}|g' \
                  -e 's|__TAG__|${IMAGE_TAG}|g' \
                  docker-compose.yml > docker-compose.ec2.yml

              # Copy compose file to EC2 and deploy
              scp -o StrictHostKeyChecking=no -i ${EC2_KEY} docker-compose.ec2.yml ec2-user@${EC2_IP}:/home/ec2-user/docker-compose.yml
              ssh -o StrictHostKeyChecking=no -i ${EC2_KEY} ec2-user@${EC2_IP} << EOF
                AWS_REGION="${AWS_REGION}"
                ACCOUNT_ID="${AWS_ACCOUNT_ID}"
                aws ecr get-login-password --region $AWS_REGION | \
                docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                docker-compose -f /home/ec2-user/docker-compose.yml up -d --remove-orphans
              EOF
            """
          }
        }
      }
    }
  }

  post {
    success {
      echo "Deployment successful! App is live on EC2."
    }
    failure {
      echo "Pipeline failed. Check console output for details."
    }
    always {
      echo "Pipeline finished."
    }
  }
}
