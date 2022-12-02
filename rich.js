const { graphql } = require('@octokit/graphql');
const { clock } = require('cli-spinners');
const { existsSync, mkdirSync } = require('fs');
const { join } = require('path');
const { exec } = require('child_process');
const enquirer = require('enquirer');
const ora = require('ora');

if (!process.argv[2]) {
    console.log('Please provide a GitHub token');
    process.exit(1);
}

const logs = [];
async function setup({ id: url, name }) {

    console.clear();
    logs.forEach(log => console.log(log));

    // ——————————————————————————————————————————————————— //

    const spinner = ora({ spinner: clock, text: `Preparing '${name}'` }).start();

    // Make directory
    const dir = join('/opt/', name);
    mkdirSync(dir);

    // Clone repository
    spinner.text = `Cloning '${name}'`;
    await exec(`git clone ${url} ${dir}`);
    const package = existsSync(join(dir, 'package.json')) ? require(join(dir, 'package.json')) : {};

    // Install dependencies
    spinner.text = `Installing dependencies for '${name}'`;
    await exec(`npm install -D`, { cwd: dir });

    // Compile if tsconfig.json exists
    if (existsSync(join(dir, 'tsconfig.json'))) {
        spinner.text = `Compiling '${name}'`;
        if (package.scripts?.build) {
            await exec(`npm run build`, { cwd: dir });
        } else {
            await exec(`tsc -p .`, { cwd: dir });
        }
    }

    // Start with pm2
    if(package.scripts?.start) {
        spinner.text = `Starting '${name}' (package.json)`;
        await exec(`pm2 start npm --name ${name} -- start`, { cwd: dir });
        logs.push(`Started '${name}'`);
    } else if(existsSync(join(dir, 'dist/index.js'))) {
        spinner.text = `Starting '${name}' (dist/index.js)`;
        await exec(`pm2 start dist/index.js --name ${name}`, { cwd: dir });
        logs.push(`Started '${name}'`);
    } else {
        logs.push(`Installed '${name}' (Not started)`);
    };

    spinner.succeed(`:3`);

}

(async () => {

    const count = (await graphql(`{ organization(login: "CactiveNetwork") { repositories { totalCount } } }`, {
        headers: {
            authorization: `bearer ${process.argv[2]}`,
        },
    })).organization.repositories.totalCount;

    const repositories = (await graphql(`{ organization(login: "CactiveNetwork") { repositories(first: ${count}) { edges { node { name url } } } } }`, {
        headers: {
            authorization: `bearer ${process.argv[2]}`,
        },
    })).organization.repositories.edges.map(({ node }) => ({ id: node.url, name: node.name }));

    // ——————————————————————————————————————————————————— //

    const prompt = new enquirer.MultiSelect({
        name: 'projects',
        message: 'Which projects would you like to setup?',
        type: '',
        choices: repositories
    });

    prompt.run()
        .then(async projects => {
            for (let project of projects) await setup(project);
        });

})();