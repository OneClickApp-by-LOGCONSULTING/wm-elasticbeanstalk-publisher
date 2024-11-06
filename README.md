# REUSABLE ACTION - Build and Deploy an WAVEMAKER application to AWS Elastic Beanstalk

Questa Action GitHub è progettata per costruire e distribuire un'applicazione WAVEMAKER su AWS Elastic Beanstalk. La pipeline automatizza il processo di compilazione dell'applicazione WAVEMAKER, il caricamento del file WAR su AWS S3, e la distribuzione su un ambiente Elastic Beanstalk specificato.

## Flusso di Lavoro

### Trigger
Questa action è configurata per essere chiamata tramite un altro workflow (`workflow_call`), il che significa che può essere riutilizzata in diversi contesti.

### Input
La action accetta i seguenti parametri di input:

- **node-version** (opzionale): Versione di Node.js da utilizzare, valore predefinito `18.16.1`.
- **maven-version** (opzionale): Versione di Maven, valore predefinito `3.9.9`.
- **java-version** (opzionale): Versione di Java da utilizzare per compilare l'applicazione, valore predefinito `21`.
- **aws-region** (opzionale): Regione AWS, valore predefinito `eu-south-1`.
- **environment-name** (obbligatorio): Nome dell'ambiente Elastic Beanstalk in cui distribuire l'applicazione.
- **wm-app-name** (opzionale): Nome dell'applicazione WAVEMAKER, valore predefinito `OneClickApp`.
- **beanstalk-application-name** (opzionale): Nome dell'applicazione AWS Elastic Beanstalk, valore predefinito `OneClickApp`.
- **wm-profile** (obbligatorio): Profilo di configurazione WAVEMAKER (es. `prod`).
- **aws-s3-bucket-name** (obbligatorio): Nome del bucket S3 su cui caricare il file WAR.
- **aws-s3-bucket-region** (obbligatorio): Regione AWS del bucket S3, valore predefinito `eu-south-1`.

### Secrets
La action richiede i seguenti segreti per poter interagire con AWS:

- **aws-access-key-id**: Chiave di accesso AWS.
- **aws-secret-access-key**: Chiave segreta AWS.

### Passaggi della Job

1. **Checkout del repository**:
   La codebase del repository viene clonata sulla macchina virtuale di GitHub.

2. **Verifica del file di configurazione WAVEMAKER**:
   Viene controllato il file di proprietà per assicurarsi che non contenga riferimenti a `wavemakeronline.com`, evitando di eseguire accidentalmente una distribuzione in un ambiente di produzione.

3. **Setup di Node.js e Maven**:
   La action configura Node.js (usando la versione specificata o quella predefinita) e Maven, incluso il caching dei pacchetti Maven per migliorare le prestazioni delle build successive.

4. **Controllo delle versioni**:
   Vengono stampate le versioni di Git, Maven, NPM, Node.js per verificare l'ambiente di build.

5. **Compilazione del WAR**:
   Esegue `mvn clean install` per costruire l'applicazione WAVEMAKER con il profilo specificato.

6. **Download di un WAR di esempio**:
   Viene scaricato un file WAR di esempio (ROOT.war) da Tomcat per scopi dimostrativi.

7. **Configurazione delle credenziali AWS**:
   Vengono configurate le credenziali AWS utilizzando le chiavi di accesso fornite tramite i segreti.

8. **Caricamento su S3 e distribuzione su Elastic Beanstalk**:
   - Il file WAR risultante (creato dalla build Maven) viene caricato su un bucket S3.
   - Viene creata una nuova versione dell'applicazione Elastic Beanstalk utilizzando il WAR caricato e aggiornato l'ambiente con questa versione.

### Esecuzione e Output

- L'Action stampa diversi messaggi di log per monitorare lo stato del processo e fornisce feedback sulla creazione, caricamento e distribuzione dell'applicazione.
- Il file WAR viene compresso in un pacchetto ZIP prima di essere caricato su S3 e distribuito tramite Elastic Beanstalk.

## Note Importanti
- Assicurati che la configurazione delle credenziali AWS e la regione AWS siano correttamente configurate per l'account e l'ambiente di destinazione.
- Il nome del bucket S3 e il nome dell'applicazione Elastic Beanstalk devono essere specificati per garantire che il processo di caricamento e distribuzione funzioni correttamente.

Per maggiori dettagli sulle release di WAVEMAKER, consulta le [WAVEMAKER Release Notes](https://docs.wavemaker.com/learn/wavemaker-release-notes/).
