pipeline {

  agent any
  
  // Define variables
  environment {
    GIT_REPO = "https://github.com/bejoykoottumkal/devops-lab.git"
     // dckr_bejoy is the id used when defining the Docker Hub credentials in Jenkins. 
    DOCKERHUB_CREDENTIALS= credentials('dckr_bejoy') 
    DOCKER_HUB_REPO = "bejoykoottumkal/devops-lab"
    ANSIBLE_SERVER_IP="52.90.96.184"   
  }  

  tools {
    maven "maven-3.6.3"
    git "Default"
  }
  
  stages {
  
    stage('Stage 1 - Checkout Code') {
      steps {
        script {
          properties([pipelineTriggers([pollSCM('')])])
        }
        //Get the code form GITHUB							
        git GIT_REPO

      }
    }
    
    stage('Stage 2 - Compile Code') {
      steps {
        //cmd to compile the code							
        sh "mvn compile"
      }
    }
    
    stage('Stage 3 - Run Unit Tests') {
      steps {
        //cmd to run tests							
        sh "mvn test"
      }
    }
    
    stage('Stage 4 -Create package') {
      steps {
        //cmd to create the build of project							
        sh "mvn package"
      }
    }
    
    stage('Stage 5 - clean install') {
      steps {
        //cmd to create the build of project							
        sh "mvn clean install"
      }
    }

    stage('Build Docker Image') {
      steps {
        sh 'sudo docker build -t ${DOCKER_HUB_REPO}:$BUILD_NUMBER .'
        echo 'Build Image Completed'
      }
    }
    
    stage('Login to Docker Hub') {      	
      steps{                       	
	sh 'echo $DOCKERHUB_CREDENTIALS_PSW | sudo docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'                		
	echo 'Login Completed'      
      }           
    }  
    
    stage('Push Image to Docker Hub') {
      steps {
        sh 'sudo docker push ${DOCKER_HUB_REPO}:$BUILD_NUMBER'
        echo 'Push Image Completed'
      }
    }
    
    stage('Deploy to K8s') {
	steps {
	    sshagent(credentials: ['ssh_ansible']) {
	      sh 'scp $WORKSPACE/webapp/target/webapp.war ubuntu@$ANSIBLE_SERVER_IP:/opt/k8s-lab/'
	    }	
	    sshagent(credentials: ['ssh_ansible']) {
	      sh 'ssh -o StrictHostKeyChecking=no -l ubuntu $ANSIBLE_SERVER_IP ansible-playbook -i /opt/k8s-lab/hosts /opt/k8s-lab/create-simple-devops-image.yml'
	    }
	    sshagent(credentials: ['ssh_ansible']) {
	      sh 'ssh -o StrictHostKeyChecking=no -l ubuntu $ANSIBLE_SERVER_IP ansible-playbook -i /opt/k8s-lab/hosts /opt/k8s-lab/kubernetes-devops-lab-deployment.yml'
	    }
	    sshagent(credentials: ['ssh_ansible']) {
	      sh 'ssh -o StrictHostKeyChecking=no -l ubuntu $ANSIBLE_SERVER_IP ansible-playbook -i ansible-playbook -i /opt/k8s-lab/hosts /opt/k8s-lab/kubernetes-devops-lab-service.yml'
	    }		    	    
	}    
    }
 

  }

  post {
    failure {
      //Send email to team about the failure
      //emailext body: 'Jenkins build failed', subject: 'Jenkins build failed', to: 'test1@test.com'
      echo "Email sent for Jenkins build failed"
    }
  }

}
