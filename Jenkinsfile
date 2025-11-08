pipeline {
    agent any

    environment {
        // ======== CONFIGURABLE VARIABLES ========

        // AWS region
        AWS_REGION = 'ap-south-1'

        // Terraform directory (where .tf files are)
        TERRAFORM_DIR = './terraform'

        // Docker image version/tag
        IMAGE_TAG = "latest"

        // Jenkins credentials IDs
        AWS_CREDS = 'aws-access'
        EC2_SSH_KEY = 'ec2-ssh-key'

        // ECR repositories (Terraform will create them)
        USER_REPO_NAME = "user-service-repo"
        ORDERS_REPO_NAME = "orders-service-repo"
        INVENTORY_REPO_NAME = "inventory-service-repo"

        // Local docker-compose file
        DOCKER_COMPOSE_FILE = './docker-compose.yml'
    }

    stages {

        // ===================================================
        stage('Checkout') {
            steps {
                echo "Fetching code from GitHub repository..."
                checkout scm
            }
        }

        // ===================================================
        stage('Terraform Init & Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
                    dir("${TERRAFORM_DIR}") {
                        sh '''
                            echo "Initializing Terraform..."
                            terraform init -input=false

                            echo "Validating Terraform..."
                            terraform validate

                            echo "Planning Terraform changes..."
                            terraform plan -out=tfplan -input=false

                            echo "Applying Terraform..."
                            terraform apply -auto-approve -input=false
                        '''
                    }
                }
            }
        }

        // ===================================================
        stage('Fetch Terraform Outputs') {
            steps {
                script {
                    echo "Fetching Terraform outputs..."
                    dir("${TERRAFORM_DIR}") {
                        USER_REPO_URL = sh(script: "terraform output -raw user_repo_url", returnStdout: true).trim()
                        ORDERS_REPO_URL = sh(script: "terraform output -raw orders_repo_url", returnStdout: true).trim()
                        INVENTORY_REPO_URL = sh(script: "terraform output -raw inventory_repo_url", returnStdout: true).trim()
                        EC2_IP = sh(script: "terraform output -raw ec2_public_ip", returnStdout: true).trim()
                    }

                    echo "Terraform Outputs Loaded:"
                    echo "User Repo: ${USER_REPO_URL}"
                    echo "Orders Repo: ${ORDERS_REPO_URL}"
                    echo "Inventory Repo: ${INVENTORY_REPO_URL}"
                    echo "EC2 IP: ${EC2_IP}"
                }
            }
        }

        // ===================================================
        stage('Build Docker Images') {
            steps {
                script {
                    echo "Building Docker images for all microservices..."
                    sh """
                        docker build -t ${USER_REPO_URL}:${IMAGE_TAG} ./user
                        docker build -t ${ORDERS_REPO_URL}:${IMAGE_TAG} ./orders
                        docker build -t ${INVENTORY_REPO_URL}:${IMAGE_TAG} ./inventory
                    """
                }
            }
        }

        // ===================================================
        stage('Push Docker Images to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
                    script {
                        echo "Logging in to AWS ECR and pushing Docker images..."
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${USER_REPO_URL%/*}

                            docker push ${USER_REPO_URL}:${IMAGE_TAG}
                            docker push ${ORDERS_REPO_URL}:${IMAGE_TAG}
                            docker push ${INVENTORY_REPO_URL}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        // ===================================================
        stage('Deploy to EC2 Instance') {
            steps {
                script {
                    echo "Deploying containers to EC2 instance: ${EC2_IP}"

                    // Substitute env vars in docker-compose template
                    sh """
                        envsubst < ${DOCKER_COMPOSE_FILE} > docker-compose-final.yml
                    """

                    // Copy to EC2 and deploy
                    sshagent(credentials: ["${EC2_SSH_KEY}"]) {
                        sh """
                            scp -o StrictHostKeyChecking=no docker-compose-final.yml ec2-user@${EC2_IP}:/home/ec2-user/deploy/docker-compose.yml

                            ssh -o StrictHostKeyChecking=no ec2-user@${EC2_IP} '
                                cd /home/ec2-user/deploy &&
                                docker-compose down || true &&
                                docker-compose pull &&
                                docker-compose up -d
                            '
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline executed successfully!"
        }
        failure {
            echo "Pipeline failed. Check console output for errors."
        }
    }
}
