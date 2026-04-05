///| JS-exported plan API for browser/worker environments.

///|
pub fn js_plan_workflow(
  yaml_text : String,
  workspace_root : String,
) -> PlanResult {
  plan_workflow(yaml_text, workspace_root~)
}

///|
pub fn js_plan_result_to_json(result : PlanResult) -> String {
  plan_result_to_json(result)
}
