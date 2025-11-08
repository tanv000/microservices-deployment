### **Overall CI/CD Workflow of Microservices Project**

#### **Step 1: Code Management**

*   The microservices’ code (user, orders, inventory) is stored in **GitHub repositories**.
    
*   Each microservice has its own repository with a Dockerfile to build its image.
    
*   **CI/CD trigger**: Whenever there is a new commit or push to the main branch, Jenkins pipeline starts automatically.
    

#### **Step 2: Infrastructure Provisioning (Terraform)**

*   Before building and deploying the application, the **infrastructure is provisioned automatically** using Terraform. This includes:
    
    1.  **ECR Repositories**:
        
        *   Each microservice has its own ECR repository.
            
        *   Docker images will be pushed here after building.
            
    2.  **EC2 Instances**:
        
        *   Instances are created to host the Docker containers.
            
        *   Security groups are attached to allow:
            
            *   SSH access (port 22) for admin access.
                
            *   Microservice ports (5001–5003) for HTTP traffic.
                
    3.  **IAM Roles and Policies**:
        
        *   EC2 instances are granted permissions to pull Docker images from ECR.
            
    4.  **Networking**:
        
        *   VPC, subnets, and other networking configurations are automatically set.
            
*   **Benefit**: No manual setup of servers, IAM roles, or repositories is needed; everything is automated.
    

#### **Step 3: Building Docker Images**

*   Jenkins clones the latest code from GitHub for each microservice.
    
*   Jenkins runs the **Docker build** command using the microservice’s Dockerfile.
    
*   The output is a **Docker image** ready to be deployed.
    

#### **Step 4: Pushing Docker Images to ECR**

*   After building, Jenkins tags the image with the ECR repository URL.
    
*   Jenkins pushes the Docker images to the respective **AWS ECR repositories**.
    
*   **Why ECR?**
    
    *   Centralized storage for Docker images.
        
    *   Integrated with AWS for secure and efficient image retrieval.
        

#### **Step 5: Deploying to EC2**

*   On EC2 instances:
    
    1.  Docker is already installed.
        
    2.  Security groups allow access to microservice ports.
        
*   Jenkins triggers Docker commands to **pull the images from ECR**.
    
*   Docker containers are **run on EC2**:
    
    *   Each microservice container maps its internal port 5000 to external ports 5001, 5002, 5003.
        
*   **Outcome**: All microservices are running and accessible on the EC2 instance’s public IP and their respective ports.
    

#### **Step 6: Verification**

*   You can verify running containers on EC2 using:
    `   docker ps   `

*   Check that the containers are up and mapping the correct ports.
    
*   Access microservices using:
    `  http://<EC2_PUBLIC_IP>:5001  `
    `  http://<EC2_PUBLIC_IP>:5002  `
    `  http://<EC2_PUBLIC_IP>:5003  ` 
