pipeline {
    agent any

    environment {
        REGION = 'ap-south-1'
        IMAGE_TAG = "latest"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/tanv000/microservices-deployment.git'
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                dir('terraform') {
                    withAWS(credentials: 'aws-access', region: "${REGION}") {
                        sh '''
                            # Initialize the S3 backend. The '-reconfigure' flag is used to switch
                            # from local to remote state storage on the first run after this change.
                            # It is safe to use on subsequent runs as well.
                            terraform init -input=false -reconfigure
                            
                            # The first 'apply' will create the S3 bucket and DynamoDB lock table
                            # before provisioning the rest of the infrastructure.
                            terraform plan -out=tfplan -input=false
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Get Terraform Outputs') {
            steps {
                dir('terraform') {
                    script {
                        env.USER_REPO      = sh(script: 'terraform output -raw user_repo_url', returnStdout: true).trim()
                        env.ORDERS_REPO    = sh(script: 'terraform output -raw orders_repo_url', returnStdout: true).trim()
                        env.INVENTORY_REPO = sh(script: 'terraform output -raw inventory_repo_url', returnStdout: true).trim()
                        env.EC2_IP         = sh(script: 'terraform output -raw ec2_public_ip', returnStdout: true).trim()
                        env.AWS_ACCOUNT_ID = sh(script: 'terraform output -raw aws_account_id', returnStdout: true).trim()
                    }
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                withAWS(credentials: 'aws-access', region: "${REGION}") {
                    script {
                        // AWS ECR Login
                        sh "aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

                        // Build and Push User Service
                        dir('user-service') {
                            sh "docker build -t microservice-user:${IMAGE_TAG} ."
                            sh "docker tag microservice-user:${IMAGE_TAG} ${USER_REPO}:${IMAGE_TAG}"
                            sh "docker push ${USER_REPO}:${IMAGE_TAG}"
                        }

                        // Build and Push Orders Service
                        dir('orders-service') {
                            sh "docker build -t microservice-orders:${IMAGE_TAG} ."
                            sh "docker tag microservice-orders:${IMAGE_TAG} ${ORDERS_REPO}:${IMAGE_TAG}"
                            sh "docker push ${ORDERS_REPO}:${IMAGE_TAG}"
                        }

                        // Build and Push Inventory Service
                        dir('inventory-service') {
                            sh "docker build -t microservice-inventory:${IMAGE_TAG} ."
                            sh "docker tag microservice-inventory:${IMAGE_TAG} ${INVENTORY_REPO}:${IMAGE_TAG}"
                            sh "docker push ${INVENTORY_REPO}:${IMAGE_TAG}"
                        }
                    }
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')]) {
                    script {
                        // Copy deploy file (ensures we use the current repo URLs)
                        sh '''
                            cp docker-compose.yml docker-compose.deploy.yml
                            sed -i "s|USER_REPO_PLACEHOLDER|${USER_REPO}|g" docker-compose.deploy.yml
                            sed -i "s|ORDERS_REPO_PLACEHOLDER|${ORDERS_REPO}|g" docker-compose.deploy.yml
                            sed -i "s|INVENTORY_REPO_PLACEHOLDER|${INVENTORY_REPO}|g" docker-compose.deploy.yml
                        '''

                        // Deploy to EC2
                        sh """
                            echo "Deploying to EC2: ${EC2_IP}"
                            scp -o StrictHostKeyChecking=no -i "\$SSH_KEY_FILE" docker-compose.deploy.yml \$SSH_USER@${EC2_IP}:/home/ec2-user/deploy/docker-compose.yml

                            ssh -o StrictHostKeyChecking=no -i "\$SSH_KEY_FILE" \$SSH_USER@${EC2_IP} "
                                mkdir -p /home/ec2-user/deploy

                                # Login to ECR on EC2
                                aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

                                # Pull and run containers
                                cd /home/ec2-user/deploy
                                docker-compose pull
                                docker-compose up -d
                            "
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline executed successfully! Infrastructure state is now stored in S3."
        }
        failure {
            echo "Pipeline failed. Check Jenkins logs."
        }
    }
}