import tseslint from '@typescript-eslint/eslint-plugin';

export default [
  {
    plugins: { '@typescript-eslint': tseslint },
    rules: { '@typescript-eslint/no-explicit-any': 'error' }
  }
];
