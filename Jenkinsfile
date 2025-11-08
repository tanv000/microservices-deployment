pipeline {
    agent any

    environment {
        AWS_CREDENTIALS = credentials('aws-access')        // Jenkins AWS credentials (Access + Secret key)
        SSH_KEY = credentials('ec2-ssh-key')               // Jenkins SSH private key credentials
        AWS_REGION = 'ap-south-1'
        TF_DIR = './terraform'
        DOCKER_COMPOSE_FILE = 'docker-compose.yml'
        IMAGE_TAG = 'latest'

        // Docker image names (logical identifiers)
        USER_IMAGE = 'user-service'
        ORDER_IMAGE = 'order-service'
        INVENTORY_IMAGE = 'inventory-service'
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo "Cloning project repository..."
                git branch: 'main', url: 'https://github.com/tanv000/microservices-deployment.git'
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TF_DIR}") {
                    echo "Initializing Terraform..."
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Terraform Plan & Apply') {
            steps {
                dir("${TF_DIR}") {
                    echo "Planning and Applying Terraform..."
                    sh 'terraform plan -out=tfplan -input=false'
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }

        stage('Extract Terraform Outputs') {
            steps {
                dir("${TF_DIR}") {
                    echo "Fetching Terraform outputs..."
                    script {
                        env.EC2_PUBLIC_IP = sh(script: "terraform output -raw ec2_public_ip", returnStdout: true).trim()
                        env.ACCOUNT_ID = sh(script: "terraform output -raw aws_account_id", returnStdout: true).trim()
                        echo "EC2 Public IP: ${env.EC2_PUBLIC_IP}"
                        echo "AWS Account ID: ${env.ACCOUNT_ID}"
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                echo "Building Docker images for all microservices..."
                sh """
                    docker build -t ${USER_IMAGE}:${IMAGE_TAG} ./user-service
                    docker build -t ${ORDER_IMAGE}:${IMAGE_TAG} ./order-service
                    docker build -t ${INVENTORY_IMAGE}:${IMAGE_TAG} ./inventory-service
                """
            }
        }

        stage('Login to AWS ECR') {
            steps {
                echo "Logging into AWS ECR..."
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login \
                        --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                """
            }
        }

        stage('Tag & Push Docker Images to ECR') {
            steps {
                echo "Tagging and pushing Docker images..."
                sh """
                    docker tag ${USER_IMAGE}:${IMAGE_TAG} ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${USER_IMAGE}:${IMAGE_TAG}
                    docker tag ${ORDER_IMAGE}:${IMAGE_TAG} ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ORDER_IMAGE}:${IMAGE_TAG}
                    docker tag ${INVENTORY_IMAGE}:${IMAGE_TAG} ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${INVENTORY_IMAGE}:${IMAGE_TAG}

                    docker push ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${USER_IMAGE}:${IMAGE_TAG}
                    docker push ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ORDER_IMAGE}:${IMAGE_TAG}
                    docker push ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${INVENTORY_IMAGE}:${IMAGE_TAG}
                """
            }
        }

        stage('Update Docker Compose') {
            steps {
                echo "Updating docker-compose.yml with ECR image URIs..."
                sh """
                    sed -i "s|__USER_REPO__|${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${USER_IMAGE}|g" ${DOCKER_COMPOSE_FILE}
                    sed -i "s|__ORDERS_REPO__|${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ORDER_IMAGE}|g" ${DOCKER_COMPOSE_FILE}
                    sed -i "s|__INVENTORY_REPO__|${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${INVENTORY_IMAGE}|g" ${DOCKER_COMPOSE_FILE}
                    sed -i "s|__TAG__|${IMAGE_TAG}|g" ${DOCKER_COMPOSE_FILE}
                """
            }
        }

        stage('Deploy on EC2') {
            steps {
                echo "Deploying on EC2 via SSH..."
                sh """
                    scp -o StrictHostKeyChecking=no -i ${SSH_KEY} ${DOCKER_COMPOSE_FILE} ec2-user@${EC2_PUBLIC_IP}:/home/ec2-user/
                    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ec2-user@${EC2_PUBLIC_IP} '
                        docker-compose down || true
                        docker-compose pull
                        docker-compose up -d
                    '
                """
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline executed successfully. Deployment completed!"
        }
        failure {
            echo "❌ Pipeline failed. Check Jenkins logs for errors."
        }
    }
}
