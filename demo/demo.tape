Output demo/cloud-secure-pipeline.gif

Set Shell "bash"
Set FontSize 16
Set Width 1100
Set Height 500
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 12ms

Hide
Type "export AWS_PAGER='' && export PS1='$ ' && clear"
Enter
Sleep 2s
Show

# 1. Zero inbound rules on the k3s node's security group
Type "aws ec2 describe-security-groups --group-ids sg-002259525f276c430 --query 'SecurityGroups[0].IpPermissions'"
Enter
Sleep 2s

# 2. No public IP either
Type "aws ec2 describe-instances --instance-ids i-0b3787c668d42928c --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,PrivateIpAddress]' --output text"
Enter
Sleep 2s

# 3. Shell on the node anyway - no key, no open port
Type "aws ssm start-session --target i-0b3787c668d42928c"
Enter
Sleep 5s

# 4. The workloads
Type "sudo kubectl get pods"
Enter
Sleep 2s

# 5. Secret read from Secrets Manager via IMDS
Type "curl -s http://10.43.103.94:5000/config"
Enter
Sleep 2s

Type "exit"
Enter
Sleep 2s