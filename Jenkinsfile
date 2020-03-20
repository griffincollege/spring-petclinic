pipeline {
  agent {
    kubernetes {
      defaultContainer 'jnlp'
      yaml """
apiVersion: v1
kind: Pod
metadata:
  namespace: mgt
  name: redcloud3-builder
  labels:
    app: redcloud3-builder
spec:
  serviceAccountName: jenkins
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug-v0.17.1
    imagePullPolicy: Always
    command:
    - /busybox/sh
    - "-c"
    args:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /kaniko/.docker
  - name: ubuntu
    image: ubuntu:18.04
    command:
    - cat
    tty: true
  - name: python
    image: python:2.7
    command:
    - cat
    tty: true
  - name: maven
    image: maven:3.6.1-jdk-8-alpine
    command:
    - cat
    tty: true
    volumeMounts:
      - name: maven-m2-repository
        mountPath: /root/.m2/repository
      - name: maven-settings
        mountPath: /root/.m2
  - name: selenium
    image: selenium/standalone-chrome:3.141.59
  - name: zap
    image: owasp/zap2docker-stable:2.9.0
    command:
    - cat
    tty: true
    env:
    - name: MY_POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
  volumes:
  - name: maven-m2-repository
    persistentVolumeClaim:
      claimName: jenkins-agent
  - name: maven-settings
    configMap:
      name: jenkins-agent-maven-settings
      items:
        - key: settings.xml
          path: settings.xml
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: docker-registry-credentials
          items:
            - key: .dockerconfigjson
              path: config.json
"""
    }
  }

  environment {
    MANAGEMENT_NAMESPACE = "mgt"
    GITHUB_GROUP = "griffincollege"
    GITHUB_PROJECT = "spring-petclinic"
    DEVCLOUD_REGISTRY_ADDRESS = "docker-nexus-mgt-jenkins-test-2.perspectatechdemos.com"
    APPLICATION_MAJOR_VERSION = "1"
    APPLICATION_MINOR_VERSION = "0"
    DEVCLOUD_DOCKER_TAG = "${DEVCLOUD_REGISTRY_ADDRESS}/${GITHUB_PROJECT}:${APPLICATION_MAJOR_VERSION}.${APPLICATION_MINOR_VERSION}.${env.BUILD_NUMBER}"
    DEVCLOUD_BRANCH_TAG = "master"
    MATTERMOST_CHANNEL = "griffincollege-spring-petclinic"
    MATTERMOST_WEBHOOK = "https://mattermost-mgt-jenkins-test-2.perspectatechdemos.com/hooks/bawmo4xb47np8yxu1mq8nhpm8y"
    ARTIFACTORY_URL = "https://artifactory-mgt-jenkins-test-2.perspectatechdemos.com"
    SONARQUBE_URL = "https://sonarqube-mgt-jenkins-test-2.perspectatechdemos.com"
    GITHUB_URL = "https://github.com"
    DEV_DEPLOYMENT_URL = "http://griffincollege-spring-petclinic-dev.apps.jenkins-test-2.perspectatechdemos.com"
    TEST_DEPLOYMENT_URL = "http://griffincollege-spring-petclinic-test.apps.jenkins-test-2.perspectatechdemos.com"
    PROD_DEPLOYMENT_URL = "http://griffincollege-spring-petclinic-prod.apps.jenkins-test-2.perspectatechdemos.com"
  }

  // triggers { pollSCM '* * * * *' }
  options {
    disableConcurrentBuilds()
    skipDefaultCheckout()
  }

  stages {
    stage('Build') {
      steps {
        updateGitlabCommitStatus name: 'build', state: 'pending'
        container('maven') {
          sh 'pwd;ls -al'
	  checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'griffincollege-token', url: "${GITHUB_URL}/${GITHUB_GROUP}/${GITHUB_PROJECT}.git"]]] 
          dir('.') {
            sh 'ls -al'
            sh 'mvn compile'
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}"
      }
    }
    stage('Test') {
      steps {
        container('maven') {
          dir('.') {
            sh 'ls -al'
            sh 'mvn test'
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}"
      }
    }
    stage('SAST') {
      steps {
        container('maven') {
          dir('.') {
            withSonarQubeEnv('sonarqube') { 
            sh "mvn compile && mvn sonar:sonar -Dsonar.projectKey=${GITHUB_GROUP}-${GITHUB_PROJECT}"
            }
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nStatic Application Security Test: ${SONARQUBE_URL}/dashboard?id=${GITHUB_GROUP}-${GITHUB_PROJECT}"
      }
    }
    stage('SAST Quality Gate') {
      steps {
        container('maven') {
          timeout(time: 10, unit: 'MINUTES') {
              waitForQualityGate abortPipeline: true
            }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nQuality Gate: ${SONARQUBE_URL}/dashboard?id=${GITHUB_GROUP}-${GITHUB_PROJECT}"
      }
    }    
    stage('Package') {
      steps {
        container(name: 'kaniko', shell: '/busybox/sh') {
          dir('.') {
            withEnv(['PATH+EXTRA=/busybox']) {
              sh '''#!/busybox/sh
              /kaniko/executor --whitelist-var-run --context `pwd` --destination ${DEVCLOUD_DOCKER_TAG}
              '''
            }
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nArtifact: ${ARTIFACTORY_URL}"
      }
    }
    stage('Deploy Dev') {
      steps {
        container('ubuntu') {
            sh "apt update -y && apt-get install wget git -y"
            checkout changelog: false, poll: false, scm: [$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'griffincollege-token', url: "${GITHUB_URL}/${GITHUB_GROUP}/${GITHUB_PROJECT}.git"]]]
            sh "cd /usr/local/bin && wget https://redcloud3.s3.amazonaws.com/tools/oc-4.2.9-linux.tar.gz && tar -xvf oc-4.2.9-linux.tar.gz"
          dir('.') {
            sh "sed 's#__PROJECT__#dev#g' route.yaml > route-dev.yaml"
            sh "sed 's#__PROJECT__#dev#g' service.yaml > service-dev.yaml"
            sh "sed 's#__PROJECT__#dev#g' deployment.yaml > deployment-dev.yaml"
            sh "sed -i 's#__IMAGE_TAG__#${DEVCLOUD_DOCKER_TAG}#' deployment-dev.yaml"
            sh "cat deployment-dev.yaml"
            sh "oc apply -f deployment-dev.yaml"
            sh "oc apply -f service-dev.yaml"
            sh "oc apply -f route-dev.yaml || true"
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nDevelopment URL: ${DEV_DEPLOYMENT_URL}"
      }
    }
    stage('Validate Dev') {
      steps {
        container('maven') {
          sh "echo 'selenium script validation'"
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nDevelopment URL: ${DEV_DEPLOYMENT_URL}"
      }
    }
    stage('ZAP Scan Dev') {
      steps {
        container('zap') {
          sh "/zap/zap.sh -quickurl ${DEV_DEPLOYMENT_URL} -cmd -quickprogress -quickout \${WORKSPACE}/zap_scan_dev.xml"
          // archiveArtifacts(artifacts: 'zap_scan_dev.xml')
        }
        container('python') {
          sh "echo 'this is the python container'"
          sh "pwd"
          sh "ls -al \${WORKSPACE}"
          sh "ls -al \${WORKSPACE}/zap_scan_dev.xml"
          archiveArtifacts(artifacts: 'zap_scan_dev.xml')
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nZAP Scan Dev: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nDevelopment URL: ${DEV_DEPLOYMENT_URL}"
      }
    }    
    stage('Deploy Test') {
      steps {
        container('ubuntu') {
          dir('.') {
            sh "sed 's#__PROJECT__#test#g' route.yaml > route-test.yaml"
            sh "sed 's#__PROJECT__#test#g' service.yaml > service-test.yaml"
            sh "sed 's#__PROJECT__#test#g' deployment.yaml > deployment-test.yaml"
            sh "sed -i 's#__IMAGE_TAG__#${DEVCLOUD_DOCKER_TAG}#' deployment-test.yaml"
            sh "cat deployment-test.yaml"
            sh "oc apply -f deployment-test.yaml"
            sh "oc apply -f service-test.yaml"
            sh "oc apply -f route-test.yaml || true"
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nTest URL: ${TEST_DEPLOYMENT_URL}"
      }
    }
    stage('Validate Test') {
      steps {
        container('maven') {
          sh "echo 'selenium script validation'"
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nTest URL: ${TEST_DEPLOYMENT_URL}"
      }
    }
    stage('Deploy Prod') {
      steps {
        container('ubuntu') {
          dir('.') {
            sh "sed 's#__PROJECT__#prod#g' route.yaml > route-prod.yaml"
            sh "sed 's#__PROJECT__#prod#g' service.yaml > service-prod.yaml"
            sh "sed 's#__PROJECT__#prod#g' deployment.yaml > deployment-prod.yaml"
            sh "sed -i 's#__IMAGE_TAG__#${DEVCLOUD_DOCKER_TAG}#' deployment-prod.yaml"
            sh "cat deployment-prod.yaml"
            sh "oc apply -f deployment-prod.yaml"
            sh "oc apply -f service-prod.yaml"
            sh "oc apply -f route-prod.yaml || true"
          }
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nProduction URL: ${PROD_DEPLOYMENT_URL}"
      }
    }
    stage('Validate Prod') {
      steps {
        container('maven') {
          sh "echo 'selenium script validation'"
        }
        mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "Job: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}\nProduction URL: ${PROD_DEPLOYMENT_URL}"
      }
    }       

   }

  post {
    success {
      mail body: "SUCCESS\nJob: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}", from: 'jenkins@localhost', replyTo: 'jenkins@localhost', subject: "Build ${GITHUB_PROJECT}", to: 'jenkins@localhost'
      mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "SUCCESS\nJob: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}"
      updateGitlabCommitStatus name: 'build', state: 'success'
    }
    failure {
      mail body: "SUCCESS\nJob: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}", from: 'jenkins@localhost', replyTo: 'jenkins@localhost', subject: "FAILURE Build ${GITHUB_PROJECT}", to: 'jenkins@localhost'
      mattermostSend channel: "${MATTERMOST_CHANNEL}", endpoint: "${MATTERMOST_WEBHOOK}", message: "FAILED\nJob: ${JOB_NAME} \nStage: ${STAGE_NAME}\nBuild: ${BUILD_URL}\nCommit: ${GITHUB_URL}"
      updateGitlabCommitStatus name: 'build', state: 'failed'
    }
  }
}
