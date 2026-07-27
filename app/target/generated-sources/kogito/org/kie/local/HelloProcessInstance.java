package org.kie.local;

import org.kie.local.HelloModel;

public class HelloProcessInstance extends org.kie.kogito.process.impl.AbstractProcessInstance<HelloModel> {

    public HelloProcessInstance(org.kie.local.HelloProcess process, HelloModel value, org.kie.api.runtime.process.ProcessRuntime processRuntime) {
        super(process, value, processRuntime);
    }

    public HelloProcessInstance(org.kie.local.HelloProcess process, HelloModel value, java.lang.String businessKey, org.kie.api.runtime.process.ProcessRuntime processRuntime) {
        super(process, value, businessKey, processRuntime);
    }

    public HelloProcessInstance(org.kie.local.HelloProcess process, HelloModel value, org.kie.api.runtime.process.ProcessRuntime processRuntime, org.kie.api.runtime.process.WorkflowProcessInstance wpi) {
        super(process, value, processRuntime, wpi);
    }

    public HelloProcessInstance(org.kie.local.HelloProcess process, HelloModel value, org.kie.api.runtime.process.WorkflowProcessInstance wpi) {
        super(process, value, wpi);
    }

    public HelloProcessInstance(org.kie.local.HelloProcess process, HelloModel value, java.lang.String businessKey, org.kie.api.runtime.process.ProcessRuntime processRuntime, org.kie.kogito.correlation.CompositeCorrelation correlation) {
        super(process, value, businessKey, processRuntime, correlation);
    }

    protected java.util.Map<String, Object> bind(HelloModel variables) {
        if (null != variables)
            return variables.toMap();
        else
            return new java.util.HashMap();
    }

    protected void unbind(HelloModel variables, java.util.Map<String, Object> vmap) {
        variables.fromMap(this.id(), vmap);
    }
}
