# CNTF
Source code repository for CNTF configurations

Project Structure:
```
├── open5gs                          contains infrastructure-as-code and helm configurations for open5gs
│   ├── infrastructure
|      	├── eks
|           └── provider.tf
|           └── main.tf
|           └── variables.tf
|           └── outputs.tf 
|   ├── application
|	      └── README.md
|	     
├── free5gc                          contains infrastructure-as-code and helm configurations for free5gc
|   ├── infrastructure
|       ├── eks
|           └── provider.tf
|           └── main.tf
|           └── variables.tf
|           └── outputs.tf 
|
|   ├── application
|       └── README.md
|
├── magma                            contains infrastructure-as-code and helm configurations for magma
|   ├── infrastructure
|       ├── eks
|           └── provider.tf
|           └── main.tf
|           └── variables.tf
|           └── outputs.tf 
|    
|   ├── application
|       └── README.md
```
