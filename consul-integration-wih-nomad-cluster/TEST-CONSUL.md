# Testing Consul Service Discovery for nginx-demo

## ✅ Current Status

Based on the output you shared:
- **nginx-demo job is RUNNING** ✓
- **3 instances are deployed and healthy** ✓
- **All allocations are in running status** ✓

```
Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost  Unknown
web         0       0         3        0       0         0     0
```

## 🧪 How to Test

### Step 1: Check Which Client VMs Are Running Nginx

SSH into the server VM:
```bash
orb -m server-vm-0
```

Then get the allocation details:
```bash
nomad job status nginx-demo
```

Look at the "Allocations" section - it shows which Node ID is running each instance.

To see which VMs these correspond to:
```bash
nomad node status
```

### Step 2: Test Nginx Direct Access

From the server VM, test each client VM directly:
```bash
# Find the client IPs
nomad node status -verbose | grep client

# Test each one (replace with actual IPs from your setup)
curl http://192.168.139.113:8080
curl http://192.168.139.64:8080
curl http://192.168.139.193:8080
```

### Step 3: Test Consul Service Discovery

#### Method A: Using Consul DNS (from inside server VM)

```bash
# SSH into server VM
orb -m server-vm-0

# Query Consul DNS
dig @localhost -p 8600 nginx-service.service.consul

# Or with SRV records (includes port)
dig @localhost -p 8600 nginx-service.service.consul SRV

# Test via DNS name
curl http://nginx-service.service.consul:8080
```

#### Method B: Using Consul API

```bash
# List all services
curl http://localhost:8500/v1/catalog/services | jq

# Get nginx-service details
curl http://localhost:8500/v1/catalog/service/nginx-service | jq

# Get healthy instances only
curl http://localhost:8500/v1/health/service/nginx-service?passing | jq
```

### Step 4: Access Consul UI

Open in your browser:
```
http://192.168.139.112:8500/ui
http://192.168.139.224:8500/ui
http://192.168.139.20:8500/ui
```

Navigate to:
1. **Services** tab
2. Click on **nginx-service**
3. You should see 3 healthy instances

### Step 5: Test Load Balancing

From inside a VM, run multiple requests:
```bash
# SSH into server VM
orb -m server-vm-0

# Run 10 requests to see different instances respond
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://nginx-service.service.consul:8080 | grep -i "welcome to nginx"
done
```

## 🔍 Troubleshooting

### If nginx-service doesn't appear in Consul:

1. **Check Nomad-Consul integration:**
   ```bash
   # SSH into server VM
   orb -m server-vm-0
   
   # Check Nomad server config
   sudo cat /etc/nomad.d/server.hcl | grep -A 5 consul
   ```

2. **Check Consul members:**
   ```bash
   consul members
   ```
   All 6 VMs should be listed.

3. **Check Nomad allocation logs:**
   ```bash
   # Get allocation ID from: nomad job status nginx-demo
   nomad alloc logs <allocation-id>
   ```

4. **Verify service registration:**
   ```bash
   # Check what services are registered
   consul catalog services
   
   # Check for any Nomad services
   consul catalog service nomad
   ```

### If DNS resolution doesn't work:

The `.service.consul` DNS only works **inside the VMs**. From your Mac:

1. **Option 1: Query Consul DNS from Mac:**
   ```bash
   dig @192.168.139.112 -p 8600 nginx-service.service.consul
   ```

2. **Option 2: Use Consul API from Mac:**
   ```bash
   # Get service instances
   curl http://192.168.139.112:8500/v1/catalog/service/nginx-service | jq
   
   # Get the IP of a healthy instance
   NGINX_IP=$(curl -s http://192.168.139.112:8500/v1/health/service/nginx-service?passing | jq -r '.[0].Service.Address')
   
   # Access nginx
   curl http://$NGINX_IP:8080
   ```

3. **Option 3: Access via direct IP from Mac:**
   ```bash
   # These should all work from your Mac
   curl http://192.168.139.113:8080
   curl http://192.168.139.64:8080
   curl http://192.168.139.193:8080
   ```

## 📊 Expected Results

### ✅ Successful Test Output

**Consul Members:**
```
server-vm-0  192.168.139.112:8301  alive   server  1.17.0  2  dc1
server-vm-1  192.168.139.224:8301  alive   server  1.17.0  2  dc1
server-vm-2  192.168.139.20:8301   alive   server  1.17.0  2  dc1
client-vm-0  192.168.139.113:8301  alive   client  1.17.0  2  dc1
client-vm-1  192.168.139.64:8301   alive   client  1.17.0  2  dc1
client-vm-2  192.168.139.193:8301  alive   client  1.17.0  2  dc1
```

**Consul Services:**
```
consul
nginx-service
nomad
nomad-client
```

**Nginx Response:**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

## 🎯 Quick Test Commands

Run these in sequence from your Mac:

```bash
# 1. Check Consul cluster
orb -m server-vm-0 consul members

# 2. Check Consul services
orb -m server-vm-0 consul catalog services

# 3. Check nginx service details
orb -m server-vm-0 'curl -s http://localhost:8500/v1/health/service/nginx-service?passing | jq'

# 4. Test DNS resolution
orb -m server-vm-0 'dig @localhost -p 8600 nginx-service.service.consul +short'

# 5. Test actual nginx access via Consul DNS
orb -m server-vm-0 'curl -s http://nginx-service.service.consul:8080 | head -5'

# 6. Test direct access from your Mac
curl http://192.168.139.113:8080
curl http://192.168.139.64:8080
curl http://192.168.139.193:8080
```

## 🌐 Accessing the Services

### From Your Mac (Host Machine):

1. **Consul UI:**
   - http://192.168.139.112:8500/ui
   
2. **Nginx Direct Access:**
   - http://192.168.139.113:8080
   - http://192.168.139.64:8080
   - http://192.168.139.193:8080

3. **Nomad UI:**
   - http://192.168.139.112:4646/ui

### From Inside VMs:

1. **Nginx via Consul DNS:**
   - http://nginx-service.service.consul:8080

2. **Consul UI:**
   - http://localhost:8500/ui

3. **Nomad UI:**
   - http://localhost:4646/ui

---

## Summary

Your setup is **WORKING** ✅:
- Nomad job is running with 3 healthy instances
- All VMs are up and running
- Consul cluster should have all 6 members

To verify Consul service discovery is working, **run the Quick Test Commands** above from your terminal!
