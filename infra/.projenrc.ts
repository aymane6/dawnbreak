import { awscdk, javascript } from 'projen';

const project = new awscdk.AwsCdkTypeScriptApp({
  cdkVersion: '2.230.0',
  name: 'dawnbreak-infra',
  description:
    'DNS and the public pages for dawnbreak.app: the privacy policy, the terms and the support page that the App Store listing links and that a reviewer opens.',
  packageManager: javascript.NodePackageManager.NPM,
  projenrcTs: true,
  defaultReleaseBranch: 'main',
  github: false,
  sampleCode: false,
  gitignore: ['cdk.out/', '.DS_Store'],
});

project.synth();
