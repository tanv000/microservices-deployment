pipeline {
    agent any

    environment {
        AWS_CREDENTIALS = credentials('aws-access')    // Jenkins credentials ID for AWS (Access + Secret key)
        SSH_KEY = credentials('ec2-ssh-key')           // Jenkins SSH key credential ID
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
                            terraform init -input=false
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
                        env.USER_REPO_URL      = sh(script: 'terraform output -raw user_repo_url', returnStdout: true).trim()
                        env.ORDERS_REPO_URL    = sh(script: 'terraform output -raw orders_repo_url', returnStdout: true).trim()
                        env.INVENTORY_REPO_URL = sh(script: 'terraform output -raw inventory_repo_url', returnStdout: true).trim()
                        env.EC2_IP             = sh(script: 'terraform output -raw ec2_public_ip', returnStdout: true).trim()
                        env.AWS_ACCOUNT_ID     = sh(script: 'terraform output -raw aws_account_id', returnStdout: true).trim()
                    }

                    echo "ECR URLs:"
                    echo "User Repo: ${env.USER_REPO_URL}"
                    echo "Orders Repo: ${env.ORDERS_REPO_URL}"
                    echo "Inventory Repo: ${env.INVENTORY_REPO_URL}"
                    echo "EC2 IP: ${env.EC2_IP}"
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                withAWS(credentials: 'aws-access', region: "${REGION}") {
                    script {
                        sh '''
                            echo "Logging into ECR..."
                            aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

                            echo "Building and pushing images..."
                            docker build -t user-service:latest ./user
                            docker tag user-service:latest ${USER_REPO_URL}:${IMAGE_TAG}
                            docker push ${USER_REPO_URL}:${IMAGE_TAG}

                            docker build -t order-service:latest ./orders
                            docker tag order-service:latest ${ORDERS_REPO_URL}:${IMAGE_TAG}
                            docker push ${ORDERS_REPO_URL}:${IMAGE_TAG}

                            docker build -t inventory-service:latest ./inventory
                            docker tag inventory-service:latest ${INVENTORY_REPO_URL}:${IMAGE_TAG}
                            docker push ${INVENTORY_REPO_URL}:${IMAGE_TAG}
                        '''
                    }
                }
            }
        }

        stage('Prepare Docker Compose for Deployment') {
            steps {
                script {
                    sh '''
                        cp docker-compose.yml docker-compose.ec2.yml

                        sed -i "s|__USER_REPO__|${USER_REPO_URL}|g" docker-compose.ec2.yml
                        sed -i "s|__ORDERS_REPO__|${ORDERS_REPO_URL}|g" docker-compose.ec2.yml
                        sed -i "s|__INVENTORY_REPO__|${INVENTORY_REPO_URL}|g" docker-compose.ec2.yml
                        sed -i "s|__TAG__|${IMAGE_TAG}|g" docker-compose.ec2.yml
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    echo "Deploying to EC2: ${EC2_IP}"
                    sh """
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY} docker-compose.ec2.yml ec2-user@${EC2_IP}:/home/ec2-user/deploy/docker-compose.yml

                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ec2-user@${EC2_IP} '
                            cd /home/ec2-user/deploy
                            sudo docker-compose down || true
                            sudo docker-compose pull
                            sudo docker-compose up -d
                        '
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline executed successfully!"
        }
        failure {
            echo "Pipeline failed. Check Jenkins logs."
        }
    }
}
