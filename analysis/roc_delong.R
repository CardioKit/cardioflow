require(pROC)

aucs_fed <- read.csv("~/Documents/GitHub/cardioflow/analysis/results/aucs_federated_finetuned.txt")
aucs_cen <- read.csv("~/Documents/GitHub/cardioflow/analysis/results/aucs_centered.txt")

ftResEmb <- aucs_fed$FTResEmb
fedResEmb <- aucs_fed$FedResEmb
cenResEmb <- aucs_cen$CenResEmb

ftRes <- aucs_fed$FTRes
fedRes <- aucs_fed$FedRes
cenRes <- aucs_cen$CenRes

label_fed <- aucs_fed$Label
label_cen <- aucs_cen$Label

roc_ftResEmb <- roc(label_fed, ftResEmb)
roc_fedResEmb <- roc(label_fed, fedResEmb)
roc_cenResEmb <- roc(label_cen, cenResEmb)

roc_fedRes <- roc(label_fed, fedRes)
roc_ftRes <- roc(label_fed, ftRes)
roc_cenRes <- roc(label_cen, cenRes)

# Choose from above variables which curve(s) to investigate
deLongResult <- roc.test(roc_fedResEmb, roc_ftRes, method = "delong")
ci_roc <- ci.auc(roc_ftResEmb, method = "delong", boot.n = 2000, conf.level = 0.95)
