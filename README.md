# azdo-default-branch-management

This repository uses modular Azure DevOps pipeline templates to automate branch permission and policy management. Below is an overview of the structure and purpose of each template, as well as how they interact in the main pipeline.

The main consideration of the design is to make the templates scalable, reusable, maintainable as well as optimizing the performance (make less api calls).

---

## Main Pipeline Entry

### `azure-pipeline.yaml`
- **Purpose:** Entry point for the pipeline. Triggers the main stage using the `azdo-branch-management.yaml` template.
- **Key Parameters:**  
  - `RepoName`: The repository to manage.
  - `failOnError`: Whether to fail the pipeline on error.

---

## Stage and Job Orchestration

### `azdo-branch-management.yaml`
- **Purpose:** Orchestrates all jobs and stages for branch management.
- **Jobs:**
  - **GetDefaultBranchInfo:** Retrieves project, repository, and default branch information.
  - **CheckBranchPermission:** Checks branch-level permissions.
  - **CheckBranchPolicy:** Checks branch review policies.
  - **SetBranchPolicy:** Sets or updates branch review policies if checks fail.
  - **SetBranchPermission:** Sets branch permissions if checks fail.
  - **GetVariables:** Outputs key variables for debugging or downstream use.
- **Job Dependencies:**  
  - Each job depends on outputs from previous jobs, ensuring correct sequencing.
- **Conditional Execution:**  
  - `SetBranchPolicy` and `SetBranchPermission` only run if their respective checks fail, using pipeline output variables and conditions.
  - `SetBranchPolicy` runs after `SetBranchPermission` since one of the required deny permission is  'EditPolicy'.

---

## Template Details

### `get-default-branch.yaml`
- **Purpose:** Fetches project ID, repository ID, and default branch name.
- **Outputs:**  
  - `DefaultBranch`, `RepoId`, `ProjectId` (as pipeline variables).
-**Consideration:**
  - This job also exports `RepoId` and `ProjectId` which can be reused by other jobs. This can reduce the number of api calls.

### `check-branch-permission.yaml`
- **Purpose:** Checks if the "Project Collection Valid Users" group is denied required permissions on the default branch.
- **Logic:**  
  - Uses REST API to fetch permissions.
  - Sets output variables:  
    - `PCVU_DESCRIPTOR`
    - `PermissionCheckStatus` (`Success` or `Failed`)
- **Consideration:**
  - In order to make sure fo checking the permission of 'everyone' for the branch, I checked 'Project Collection Valid User' corresponding effective deny permission on branch level. Because every individual/group should be included in 'Project Collection Valid User'. Also, explicit 'Deny' at any scope takes precedence and more specific scope overrides broader scope (branch > repo > project > collection) and branch level also does not affect other levels.
  - All required deny permission bits are combined together so only neend to check/call the api once. We can benefit from the design of permission bit.
     

### `check-branch-policy.yaml`
- **Purpose:** Checks if branch review policies (e.g., minimum approvers, reset on push) are set as expected.
- **Logic:**  
  - Uses REST API to fetch policies.
  - Compares actual settings to expected values.
  - Sets output variables for each policy setting (`minimumApproverCount`, `resetOnSourcePush`, `resetRejectionsOnSourcePush`) and `PolicyId`.
- **Consideration:**
  - I first check if there exists a branch policy for the scope. Then, if there is already one, the first policy will be update. This can avoid keeping creating new policies,
  because there could be a limit for the number of polices. And if there are policies, it will cause performance issue since PR creation and updates can slow down noticeably because each policy evaluation runs separately
  - Since if two policies conflict, Azure DevOps always applies the more restrictive outcome. There could be the 'minimum reviewers' is more than 2. I think it can be accepted since this pipeline only set the baseline rule for the compliance.

### `set-branch-policy.yaml`
- **Purpose:** Creates or updates branch review policies if checks fail.
- **Logic:**  
  - Builds a policy payload using `jq`.
  - Calls the REST API to create or update the policy.
- **Consideration:**
  - Set policy at once if anyone of the checks failed. This can reduce api calls.

### `set-branch-permission.yaml`
- **Purpose:** Sets deny permissions for the "Project Collection Valid Users" group on the branch if permission checks fail.
- **Logic:**  
  - Calculates the deny bitmask.
  - Builds an ACL payload using `jq`.
  - Calls the REST API to update permissions.
- **Consideration:**
  - Set policy at once if anyone of the checks failed. This can reduce api calls.

---

## Shared Utilities

### `utils.sh`
- **Purpose:** Contains reusable Bash functions and configuration for API calls, permission bit calculations, and value conversions.
- **Key Functions:**
  - `convert_to_hex`: Converts branch names to hex for token construction.
  - `make_request`: Wrapper for authenticated REST API calls.
  - `get_deny_value`: Sums permission bits for deny mask.

---

## Output Variables

Each job sets output variables using the `##vso[task.setvariable ...]` syntax, which are then consumed by dependent jobs using the `dependencies` context.

---

## Example Flow

1. **GetDefaultBranchInfo** → Outputs branch/repo/project IDs.
2. **CheckBranchPermission** → Checks permissions, outputs status.
3. **CheckBranchPolicy** → Checks policies, outputs status for each.
4. **SetBranchPolicy** → Runs only if any policy check failed.
5. **SetBranchPermission** → Runs only if permission check failed.
6. **GetVariables** → Outputs all key variables for review.

---

## Extending the Pipeline

- **Add new permission or policy checks:**  
  Update the relevant check template and utility functions.
- **Add new jobs:**  
  Add to `azdo-branch-management.yaml` and define dependencies/outputs as needed.

