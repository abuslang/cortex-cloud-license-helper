document.addEventListener('DOMContentLoaded', () => {
    const calculateBtn = document.getElementById('calculate-btn');
    const resultsDiv = document.getElementById('results');
    const totalWorkloadsSpan = document.getElementById('total-workloads');
    const form = document.getElementById('license-form');

    const inputs = {
        vmsNoContainers: document.getElementById('vms-no-containers'),
        vmsWithContainers: document.getElementById('vms-with-containers'),
        caas: document.getElementById('caas'),
        serverless: document.getElementById('serverless'),
        containerImages: document.getElementById('container-images'),
        cloudBuckets: document.getElementById('cloud-buckets'),
        paasDb: document.getElementById('paas-db'),
        dbaas: document.getElementById('dbaas'),
        saasUsers: document.getElementById('saas-users'),
        unmanagedServices: document.getElementById('unmanaged-services'),
    };

    const BILLABLE_UNITS = {
        CaaS: 10,
        Serverless: 25,
        ContainerImages: 10,
        CloudBuckets: 10,
        PaaSDB: 2,
        DBaaS: 1,
        SaaSUsers: 10,
        UnmanagedServices: 4,
    };

    function getValue(element) {
        return parseInt(element.value, 10) || 0;
    }

    function calculateWorkloads() {
        let totalWorkloads = 0;

        // 1. VMs (not running containers): 1 VM = 1 workload
        const vmsNoContainersCount = getValue(inputs.vmsNoContainers);
        totalWorkloads += vmsNoContainersCount;

        // 2. VMs (running containers): 1 VM = 1 workload
        const vmsWithContainersCount = getValue(inputs.vmsWithContainers);
        totalWorkloads += vmsWithContainersCount;

        // 3. CaaS: 10 Managed Containers = 1 workload
        const caasCount = getValue(inputs.caas);
        const caasWorkloads = Math.ceil(caasCount / BILLABLE_UNITS.CaaS);
        totalWorkloads += caasWorkloads;

        // 4. Serverless Functions: 25 Functions = 1 workload
        const serverlessCount = getValue(inputs.serverless);
        totalWorkloads += Math.ceil(serverlessCount / BILLABLE_UNITS.Serverless);

        // 5. Container Images in Registries
        const deployedWorkloadsForScans = vmsNoContainersCount + vmsWithContainersCount + caasWorkloads;
        const freeScanQuota = deployedWorkloadsForScans * 10;
        const totalScans = getValue(inputs.containerImages);
        const billableScans = Math.max(0, totalScans - freeScanQuota);
        totalWorkloads += Math.ceil(billableScans / BILLABLE_UNITS.ContainerImages);
        
        // 6. Cloud Buckets: 10 buckets = 1 workload
        const cloudBucketsCount = getValue(inputs.cloudBuckets);
        totalWorkloads += Math.ceil(cloudBucketsCount / BILLABLE_UNITS.CloudBuckets);

        // 7. Managed Cloud Database (PaaS): 2 DBs = 1 workload
        const paasDbCount = getValue(inputs.paasDb);
        totalWorkloads += Math.ceil(paasDbCount / BILLABLE_UNITS.PaaSDB);

        // 8. DBaaS: 1 TB Stored = 1 workload
        const dbaasCount = getValue(inputs.dbaas);
        totalWorkloads += Math.ceil(dbaasCount / BILLABLE_UNITS.DBaaS);

        // 9. SaaS Users: 10 users = 1 workload
        const saasUsersCount = getValue(inputs.saasUsers);
        totalWorkloads += Math.ceil(saasUsersCount / BILLABLE_UNITS.SaaSUsers);

        // 10. Cloud ASM - Unmanaged Services: 4 assets = 1 workload
        const unmanagedServicesCount = getValue(inputs.unmanagedServices);
        totalWorkloads += Math.ceil(unmanagedServicesCount / BILLABLE_UNITS.UnmanagedServices);

        // Display results
        totalWorkloadsSpan.textContent = totalWorkloads;
        resultsDiv.classList.remove('hidden');
    }

    calculateBtn.addEventListener('click', calculateWorkloads);

    // Recalculate on any input change for real-time feedback
    Object.values(inputs).forEach(input => {
        input.addEventListener('input', calculateWorkloads);
    });
}); 