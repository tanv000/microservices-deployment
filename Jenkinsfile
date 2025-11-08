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
                        env.USER_REPO      = sh(script: 'terraform output -raw user_repo_url', returnStdout: true).trim()
                        env.ORDERS_REPO    = sh(script: 'terraform output -raw orders_repo_url', returnStdout: true).trim()
                        env.INVENTORY_REPO = sh(script: 'terraform output -raw inventory_repo_url', returnStdout: true).trim()
                        env.EC2_IP         = sh(script: 'terraform output -raw ec2_public_ip', returnStdout: true).trim()
                        env.AWS_ACCOUNT_ID = sh(script: 'terraform output -raw aws_account_id', returnStdout: true).trim()
                    }
                    echo "ECR URLs:"
                    echo "User Repo: ${env.USER_REPO}"
                    echo "Orders Repo: ${env.ORDERS_REPO}"
                    echo "Inventory Repo: ${env.INVENTORY_REPO}"
                    echo "EC2 IP: ${env.EC2_IP}"
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                withAWS(credentials: 'aws-access', region: "${REGION}") {
                    script {
                        def services = [
                            "user-service": env.USER_REPO,
                            "order-service": env.ORDERS_REPO,
                            "inventory-service": env.INVENTORY_REPO
                        ]

                        for (service in services.keySet()) {
                            sh """
                                echo "Building ${service}..."
                                docker build -t ${service}:${IMAGE_TAG} ./${service}
                                docker tag ${service}:${IMAGE_TAG} ${services[service]}:${IMAGE_TAG}

                                echo "Pushing ${service} to ECR..."
                                aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
                                docker push ${services[service]}:${IMAGE_TAG}
                            """
                        }
                    }
                }
            }
        }

        stage('Prepare docker-compose.yml') {
            steps {
                script {
                    // Replace placeholders in template with real ECR URLs
                    sh """
                        cp docker-compose.yml.template docker-compose.yml
                        sed -i 's|\${USER_REPO}|${USER_REPO}|g' docker-compose.yml
                        sed -i 's|\${ORDERS_REPO}|${ORDERS_REPO}|g' docker-compose.yml
                        sed -i 's|\${INVENTORY_REPO}|${INVENTORY_REPO}|g' docker-compose.yml
                    """
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')]) {
                    script {
                        sh '''
                            echo "Deploying to EC2: ${EC2_IP}"

                            # Create deploy folder
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" $SSH_USER@${EC2_IP} "mkdir -p /home/ec2-user/deploy"

                            # Copy final docker-compose.yml
                            scp -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" docker-compose.yml $SSH_USER@${EC2_IP}:/home/ec2-user/deploy/docker-compose.yml

                            # Deploy services
                            ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_FILE" $SSH_USER@${EC2_IP} << 'ENDSSH'
                                cd /home/ec2-user/deploy
                                sudo /usr/local/bin/docker-compose down || true
                                sudo /usr/local/bin/docker-compose pull
                                sudo /usr/local/bin/docker-compose up -d
ENDSSH
                        '''
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
            echo "Pipeline failed. Check logs."
        }
    }
}
