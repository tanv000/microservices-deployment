# folder structure

microservices-deployment/
│
├── user-service/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── order-service/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── inventory-service/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
│
├── docker-compose.yml
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── terraform.tfvars      # optional for your own variable values
│
├── Jenkinsfile
│
├── .gitignore
│
└── README.md
