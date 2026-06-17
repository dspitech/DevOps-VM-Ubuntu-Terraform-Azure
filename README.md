# Déployer une VM Linux Ubuntu sur Azure avec Terraform (Automatisé)

## Prérequis

- Un **abonnement Azure** actif avec les droits Contributor
- Être connecté à **Azure Cloud Shell en mode PowerShell** (ou Bash)

> Azure CLI, Terraform et l'authentification sont déjà pris en charge par Cloud Shell. Aucune installation supplémentaire n'est nécessaire.

---

## Architecture déployée

| Ressource | Valeur |
|---|---|
| Resource Group | `OpenLab-Sweden-RG` |
| Région | `swedencentral` |
| Nom de la VM | `OpenLab-VM-Student` |
| Image | Ubuntu Server 22.04 LTS |
| Taille | Standard_B2s_v2 (2 vCPU / 4 Go RAM) |
| Utilisateur admin | `labadmin` |
| Authentification | Clé SSH **générée automatiquement** par le provider `tls` |
| IP publique | Standard SKU, statique |
| Disque OS | Premium_LRS |
| Disque de données | Premium_LRS, 64 Go, monté sur `/data` |
| State Terraform | Azure Blob Storage (backend distant) |
| Logiciels pré-installés | **Docker CE + Docker Compose + Git** (via cloud-init) |

### Ports ouverts

| Port | Usage | Priorité |
|---|---|---|
| 22 | SSH | 110 |
| 443 | HTTPS | 101 |
| 3389 | RDP | 100 |
| 5900 | VNC | 103 |
| 8006 | Proxmox / Web UI | 102 |
| 8080 | HTTP alternatif | 104 |
| 8989 | Application custom | 105 |

### Fichiers du projet

```
.
├── main.tf              # Infrastructure complète
├── backend.tf           # Configuration du backend Azure Storage
├── cloud-init.yaml      # Script de provisionnement (Docker + Git)
└── scripts/
    └── setup-backend.sh # Script de création du Storage Account
```

---

## Nouveautés par rapport à la version précédente

| Fonctionnalité | Description |
|---|---|
| **Clé SSH auto** | Générée par le provider `tls`, sauvegardée localement, aucun `ssh-keygen` manuel |
| **State distant** | Stocké dans Azure Blob Storage → collaboration et persistance garanties |
| **Disque de données** | `azurerm_managed_disk` de 64 Go, attaché sur LUN 10, formaté et monté sur `/data` |
| **cloud-init** | Docker CE, Docker Compose, Git installés dès le premier démarrage |
| **Région** | `swedencentral` (anciennement `norwayeast`) |
| **Taille VM** | `Standard_B2s_v2` (anciennement `Standard_D4s_v3`) |

---

## Étape 1 - Préparer le backend Terraform (Optionnel)

Le state Terraform doit être stocké dans Azure **avant** le premier `terraform init`.

```bash
git clone https://github.com/dspitech/DevOps-Porj-Mgnt-ESTIAM.git
cd DevOps-Porj-Mgnt-ESTIAM
chmod +x ./setup-backend.sh
.setup-backend.sh

# vérifier le nom du Storage Account créé
az storage account list --resource-group OpenLab-TFState-RG --query "[].name" -o tsv
# Puis mettez-le dans backend.tf : storage_account_name = "openlabtfstate14523"   # ← le nom réel
```

Le script affiche le nom du Storage Account généré (ex. `openlabtfstate14523`).  
Copiez-le dans `backend.tf` :

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "OpenLab-TFState-RG"
    storage_account_name = "openlabtfstate14523"   # ← remplacez ici
    container_name       = "tfstate"
    key                  = "openlab-vm.terraform.tfstate"
  }
}
```

> Ce Resource Group (`OpenLab-TFState-RG`) est **indépendant** de celui de la VM. Il persiste même après `terraform destroy`.

---

## Étape 2 - Déploiement

```bash
terraform init && terraform fmt && terraform validate && terraform plan && terraform apply -auto-approve
```

Terraform va :
1. Télécharger les providers `azurerm`, `tls` et `local`
2. Générer une paire de clés RSA 4096 bits
3. Sauvegarder `openlab_rsa` (privée) et `openlab_rsa.pub` dans le répertoire courant
4. Créer les 10 ressources Azure (RG, VNet, Subnet, NSG, IP, NIC, Managed Disk, VM, attachement disque, association NIC-NSG)
5. Injecter le script `cloud-init.yaml` dans la VM

En ligne de commande PowerShell : 

```
download ./openlab_rsa
```
---

## Étape 3 - Se connecter à la VM

```powershell
ssh -i "C:\Users\dev\Downloads\openlab_rsa" devopsadmin@00.000.006.222
```

> Tapez `yes` pour accepter l'empreinte lors de la première connexion.  


---

## Étape 4 - Vérifier le provisionnement cloud-init

Docker et Git sont installés automatiquement au premier démarrage (environ 2–3 minutes après la connexion SSH).

```bash
# Suivre l'avancement en temps réel
sudo tail -f /var/log/cloud-init-output.log

# Vérifier le log de fin de provisionnement
cat /var/log/openlab-init.log

# Tester Docker
docker run --rm hello-world

# Vérifier Git
git --version

# Vérifier le disque de données monté
df -h /data
```

---

## Étape 5 - Inspecter l'état Terraform

```bash
# Lister toutes les ressources
terraform state list

# Afficher le détail de la VM
terraform state show azurerm_linux_virtual_machine.vm

# Récupérer l'IP publique
terraform output public_ip_address
```

Ressources créées :

```
azurerm_linux_virtual_machine.vm
azurerm_managed_disk.data_disk
azurerm_network_interface.nic
azurerm_network_interface_security_group_association.nic_nsg
azurerm_network_security_group.nsg
azurerm_public_ip.public_ip
azurerm_resource_group.rg
azurerm_subnet.subnet
azurerm_virtual_machine_data_disk_attachment.data_disk_attach
azurerm_virtual_network.vnet
local_file.public_key
local_sensitive_file.private_key
tls_private_key.ssh_key
```

---

## Étape 6 - Détruire l'infrastructure (optionnel)

```bash
terraform destroy -auto-approve
```

> Le Resource Group du backend (`OpenLab-TFState-RG`) et le Storage Account **ne sont pas supprimés** par `terraform destroy`, car ils ne font pas partie de la configuration `main.tf`. Supprimez-les manuellement si nécessaire :
> ```bash
> az group delete --name OpenLab-TFState-RG --yes --no-wait
> ```

---

## Résumé des étapes

| Étape | Action | Résultat |
|---|---|---|
| 1 | `./scripts/setup-backend.sh` | Storage Account backend créé |
| 2 | Mettre à jour `backend.tf` | Nom du Storage Account renseigné |
| 3 | `terraform init` | Provider Azure, TLS, Local téléchargés + backend configuré |
| 4 | `terraform apply -auto-approve` | 10 ressources Azure créées, clés SSH générées |
| 5 | `terraform output -raw ssh_command` | Commande SSH prête à l'emploi |
| 6 | SSH + `cat /var/log/openlab-init.log` | Docker et Git confirmés installés |
| 7 | `terraform destroy` | Infrastructure supprimée (backend conservé) |

---

## Dépannage

| Problème | Cause probable | Solution |
|---|---|---|
| `Backend initialization required` | `backend.tf` non mis à jour | Copiez le nom du Storage Account depuis la sortie de `setup-backend.sh` |
| `storage account name already taken` | Nom non unique | Relancez `setup-backend.sh` (le suffixe `$RANDOM` change à chaque exécution) |
| `Permission denied (publickey)` | Mauvaises permissions sur la clé | `chmod 600 openlab_rsa` |
| `file: no such file` dans Terraform | `cloud-init.yaml` absent | Vérifiez que le fichier est dans le même répertoire que `main.tf` |
| `Error: A resource with the ID already exists` | Resource Group déjà existant | Changez `rg_name` ou supprimez le RG existant |
| Docker non disponible après SSH | cloud-init encore en cours | Attendez 3 min puis reconnectez-vous |
| `/data` non monté | Disque pas encore attaché | Vérifiez `lsblk` et relancez `mount -a` |
| Timeout SSH | VM pas encore démarrée | Attendez 2 minutes après `terraform apply` |
