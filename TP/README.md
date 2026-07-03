Les principaux coûts sur ton infra :

Ressource	Coût	Comment l'arrêter
AGW WAF_v2	~$0.36/h + data	Le plus cher — doit être détruit
VMs (x2)	~$0.04/h x2	Deallocate
PostgreSQL	~$0.02/h	Stop
NAT Gateway	~$0.045/h	Doit être détruit
Option 1 — Sauvegarder le max sans tout détruire (VMs + PostgreSQL) :

# Deallocate les VMs (pas de frais compute, garde les disques)
az vm deallocate -g rg-b3-vm -n vm-backend-0
az vm deallocate -g rg-b3-vm -n vm-frontend-0

# Arrêter PostgreSQL
az postgres flexible-server stop -g rg-b3-vm --name psql-b3-tp

⚠️ L'AGW WAF_v2 et le NAT gateway continuent de coûter.

Option 2 — Tout détruire (recommandé si tu ne reviens pas avant quelques jours) :

cd "c:\Users\youce\Documents\YNOV\B3\COURS\Cloud Computing\TP\backend"
tofu destroy

Tout ton code Terraform est là → tofu apply pour tout recréer quand tu veux.

Pour redémarrer (si tu as fait l'option 1) :

az vm start -g rg-b3-vm -n vm-backend-0
az vm start -g rg-b3-vm -n vm-frontend-0
az postgres flexible-server start -g rg-b3-vm --name psql-b3-tp

le frontend (Nginx) et le backend (Node.js + Express) tournent maintenant chacun dans un container Docker sur leur VM respective, avec leurs propres Dockerfile et un docker-compose.yml pour tester en local.

L'AGW route le trafic via une health probe custom sur /health pour ne forwarder les requêtes /api/* vers le backend que lorsqu'il est réellement disponible — ce qui est exactement le pattern utilisé en production cloud.