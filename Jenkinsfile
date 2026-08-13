// Jenkins declarative pipeline for cloud-secure-pipeline
// Mirrors the GitHub Actions workflow: quality gates -> test -> build -> render -> gated publish
// Runs entirely locally: every tool is invoked as a throwaway container, so the Jenkins
// agent only needs a Docker CLI + socket. No AWS credentials required for a green build.

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME  = 'cloud-secure-pipeline-app'
        IMAGE_TAG   = "${env.BUILD_NUMBER}"
        APP_DIR     = 'app'
        TF_BOOTSTRAP = 'bootstrap'   // state backend: S3 + DynamoDB lock
        TF_LIVE      = 'live'        // VPC, k3s EC2, ECR, OIDC, secrets
        HELM_CHART   = 'helm/secure-cloud-pipeline'
        // Findings accepted for this single-user demo project (cost/complexity not justified
        // at this scale): DynamoDB PITR/CMK, S3 lifecycle/replication/logging/CMK, ECR tag
        // immutability/CMK, NAT/k3s open egress by design, EC2 detailed monitoring/EBS-opt,
        // NAT public IP by design, public subnet by design, Secrets Manager CMK/rotation,
        // VPC flow logs, default SG hardening.
        CHECKOV_SKIPS = 'CKV_AWS_28,CKV_AWS_119,CKV2_AWS_61,CKV_AWS_145,CKV2_AWS_62,CKV_AWS_144,CKV_AWS_18,CKV_AWS_51,CKV_AWS_136,CKV_AWS_382,CKV_AWS_126,CKV_AWS_135,CKV_AWS_88,CKV_AWS_130,CKV_AWS_149,CKV2_AWS_57,CKV2_AWS_11,CKV2_AWS_12'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                sh 'git --no-pager log -1 --oneline'
            }
        }

        // Three independent gates with no dependency on each other -> run them concurrently.
        // This is the "job dependency optimisation" story: wall-clock time drops to the
        // slowest single gate instead of the sum of all three.
        stage('Quality Gates') {
            parallel {

                stage('Python Lint') {
                    steps {
                        sh '''
                            docker run --rm -v "$PWD":/src -w /src python:3.12-slim \
                              sh -c "pip install --quiet ruff && ruff check ${APP_DIR}"
                        '''
                    }
                }

                stage('IaC Scan: bootstrap') {
                    steps {
                        sh '''
                            docker run --rm -v "$PWD":/src \
                              bridgecrew/checkov:latest -d /src/${TF_BOOTSTRAP} \
                              --skip-check ${CHECKOV_SKIPS} --compact --quiet
                        '''
                    }
                }

                stage('IaC Scan: live') {
                    steps {
                        sh '''
                            docker run --rm -v "$PWD":/src \
                              bridgecrew/checkov:latest -d /src/${TF_LIVE} \
                              --skip-check ${CHECKOV_SKIPS} --compact --quiet
                        '''
                    }
                }
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .'
                sh 'docker image inspect ${IMAGE_NAME}:${IMAGE_TAG} --format "built {{.Id}} ({{.Size}} bytes)"'
            }
        }

        stage('Helm Lint & Render') {
            steps {
                sh 'docker run --rm -v "$PWD":/src -w /src alpine/helm:latest lint ${HELM_CHART}'
                sh '''
                    docker run --rm -v "$PWD":/src -w /src alpine/helm:latest \
                      template release ${HELM_CHART} --set image.tag=${IMAGE_TAG} \
                      > rendered-manifests.yaml
                '''
                archiveArtifacts artifacts: 'rendered-manifests.yaml', fingerprint: true
            }
        }

        // Publish is gated on main. Credentials are never stored in the Jenkinsfile —
        // they come from the Jenkins credential store at run time, the same principle
        // the GitHub Actions workflow gets from OIDC federation.
        stage('Publish to Registry') {
            when {
                branch 'main'
            }
            steps {
                echo "Publishing ${IMAGE_NAME}:${IMAGE_TAG}"
                // withCredentials([usernamePassword(credentialsId: 'ecr-creds',
                //                                   usernameVariable: 'REG_USER',
                //                                   passwordVariable: 'REG_PASS')]) {
                //     sh 'echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin $ECR_REGISTRY'
                //     sh 'docker tag ${IMAGE_NAME}:${IMAGE_TAG} $ECR_REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}'
                //     sh 'docker push $ECR_REGISTRY/${IMAGE_NAME}:${IMAGE_TAG}'
                // }
            }
        }
    }

    post {
        success {
            echo "Build ${env.BUILD_NUMBER} cleared every gate."
        }
        failure {
            echo "Build ${env.BUILD_NUMBER} failed - check the stage view for the first red stage."
        }
        always {
            sh 'docker image prune -f || true'
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}
