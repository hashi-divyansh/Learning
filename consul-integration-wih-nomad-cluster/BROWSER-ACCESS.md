# How to Access nginx-service from Your Browser

## ❌ Why `http://nginx-service.service.consul:8080` Doesn't Work

The `.service.consul` domain is a **Consul DNS name** that only works **inside the VMs** where Consul DNS is configured. Your Mac browser doesn't know how to resolve this domain.

---

## ✅ Solution: Access Options from Your Browser

### Option 1: Direct IP Access (Easiest)

Access nginx directly on any of the 3 client VMs:

```
http://192.168.139.113:8080  (client-vm-0)
http://192.168.139.64:8080   (client-vm-1)
http://192.168.139.193:8080  (client-vm-2)
```

**Try opening these URLs in your browser now!**

---

### Option 2: Configure macOS to Resolve .consul Domain

If you want `nginx-service.service.consul` to work from your Mac:

#### Step 1: Create Consul DNS Resolver

```bash
# Create resolver directory
sudo mkdir -p /etc/resolver

# Add Consul DNS resolver (using server-vm-0 IP)
echo "nameserver 192.168.139.112
port 8600" | sudo tee /etc/resolver/consul

# Verify the file was created
cat /etc/resolver/consul
```

#### Step 2: Test DNS Resolution

```bash
# Test if DNS now works
dig nginx-service.service.consul

# Or use ping
ping nginx-service.service.consul
```

#### Step 3: Access in Browser

Now you should be able to open:
```
http://nginx-service.service.consul:8080
```

**Note:** This will round-robin between the 3 nginx instances via Consul DNS.

---

### Option 3: Use Consul DNS from Command Line

Query Consul to get the IPs, then access them:

```bash
# Get all nginx service IPs
dig @192.168.139.112 -p 8600 nginx-service.service.consul +short

# Or use Consul API
curl http://192.168.139.112:8500/v1/catalog/service/nginx-service | jq -r '.[].ServiceAddress'
```

Then open the returned IPs in your browser.

---

### Option 4: Test from Inside a VM (Console)

If browser access isn't working, verify it works inside the VMs:

```bash
# SSH into any server or client VM
orb -m server-vm-0

# Test Consul DNS
curl http://nginx-service.service.consul:8080

# You should see the nginx HTML page
```

---

## 🔧 Troubleshooting

### If Direct IP Access Doesn't Work:

1. **Check if nginx containers are actually running:**

```bash
# SSH into a client VM
orb -m client-vm-0

# Check running containers
sudo docker ps

# You should see nginx containers
```

2. **Check if port 8080 is bound:**

```bash
# From inside client VM
sudo netstat -tlnp | grep 8080

# Or
ss -tlnp | grep 8080
```

3. **Check Nomad allocation status:**

```bash
# From server VM
orb -m server-vm-0

# Get allocation details
nomad job status nginx-demo

# Check specific allocation logs
nomad alloc logs <allocation-id>
```

4. **Check firewall rules:**

```bash
# From client VM
sudo iptables -L -n | grep 8080
```

### If Consul DNS Doesn't Show nginx-service:

1. **Verify service is registered:**

```bash
# From server VM
orb -m server-vm-0

# List all services
consul catalog services

# Check nginx-service specifically
curl http://localhost:8500/v1/health/service/nginx-service | jq
```

2. **Check Nomad-Consul integration:**

```bash
# From server VM
orb -m server-vm-0

# Check if Nomad is configured to use Consul
sudo cat /etc/nomad.d/server.hcl | grep -A 10 consul
```

Expected to see:
```hcl
consul {
  address = "127.0.0.1:8500"
}
```

3. **Restart the nginx-demo job:**

```bash
# From server VM
orb -m server-vm-0

# Stop the job
nomad job stop nginx-demo

# Start it again
nomad job run /path/to/nginx.nomad.hcl
```

---

## 📊 Verification Steps

### 1. Check Consul UI (Should work from browser)

Open in your browser:
```
http://192.168.139.112:8500/ui
```

Navigate to **Services** → **nginx-service** to see all 3 instances.

### 2. Check Nomad UI (Should work from browser)

Open in your browser:
```
http://192.168.139.112:4646/ui
```

Navigate to **Jobs** → **nginx-demo** to see the running allocations.

### 3. Verify from Command Line

```bash
# From your Mac terminal

# Test Consul UI access
curl -I http://192.168.139.112:8500/ui/

# Test Nomad UI access
curl -I http://192.168.139.112:4646/ui/

# Test nginx direct access
curl -I http://192.168.139.113:8080

# Query Consul DNS from your Mac
dig @192.168.139.112 -p 8600 nginx-service.service.consul
```

---

## 🎯 Quick Fix Commands

Run these from your Mac terminal to test everything:

```bash
# 1. Test Consul UI
echo "Testing Consul UI..."
curl -s http://192.168.139.112:8500/v1/status/leader

# 2. Test Nomad UI
echo "Testing Nomad UI..."
curl -s http://192.168.139.112:4646/v1/status/leader

# 3. Query nginx service from Consul
echo "Querying nginx-service from Consul..."
curl -s http://192.168.139.112:8500/v1/catalog/service/nginx-service | jq -r '.[].ServiceAddress'

# 4. Test nginx on each client
echo "Testing nginx on client VMs..."
for ip in 192.168.139.113 192.168.139.64 192.168.139.193; do
  echo "Testing $ip:8080..."
  curl -s -m 2 http://$ip:8080 | grep -o "<title>.*</title>" || echo "Failed or timed out"
done
```

---

## ✅ Expected Working URLs for Your Browser

After your setup is verified, these should work:

1. **Consul UI:**
   - http://192.168.139.112:8500/ui ✓

2. **Nomad UI:**
   - http://192.168.139.112:4646/ui ✓

3. **Nginx Direct Access:**
   - http://192.168.139.113:8080 ✓
   - http://192.168.139.64:8080 ✓
   - http://192.168.139.193:8080 ✓

4. **Nginx via Consul DNS** (only after configuring /etc/resolver/consul):
   - http://nginx-service.service.consul:8080 ✓

---

## 🚀 Recommended Next Steps

1. **First, try accessing Consul UI** to verify basic connectivity:
   ```
   http://192.168.139.112:8500/ui
   ```

2. **Check if nginx-service appears** in the Services tab

3. **Try accessing nginx directly** at:
   ```
   http://192.168.139.113:8080
   ```

4. **If step 3 doesn't work**, SSH into the client VM and check if the container is running:
   ```bash
   orb -m client-vm-0
   sudo docker ps
   curl localhost:8080
   ```

5. **If you want browser access via Consul DNS**, configure `/etc/resolver/consul` as shown in Option 2

---

## 💡 Summary

The error you're seeing is **expected behavior** - your Mac browser cannot resolve `.service.consul` domains by default. 

**Use the direct IP addresses** (`http://192.168.139.113:8080`, etc.) or **configure the Consul DNS resolver** on your Mac to make the `.consul` domain work.
