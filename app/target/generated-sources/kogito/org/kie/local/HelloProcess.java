package org.kie.local;

import org.kie.local.HelloModel;
import org.kie.api.definition.process.Process;
import org.jbpm.ruleflow.core.RuleFlowProcessFactory;
import org.jbpm.process.core.datatype.impl.type.ObjectDataType;
import org.drools.core.util.KieFunctions;

@jakarta.enterprise.context.ApplicationScoped()
@jakarta.inject.Named("hello")
@io.quarkus.runtime.Startup()
public class HelloProcess extends org.kie.kogito.process.impl.AbstractProcess<org.kie.local.HelloModel> {

    @jakarta.inject.Inject()
    public HelloProcess(org.kie.kogito.app.Application app, org.kie.kogito.correlation.CorrelationService correlations) {
        super(app, java.util.Arrays.asList(), correlations);
        activate();
    }

    public HelloProcess() {
    }

    @Override()
    public org.kie.local.HelloProcessInstance createInstance(org.kie.local.HelloModel value) {
        return new org.kie.local.HelloProcessInstance(this, value, this.createProcessRuntime());
    }

    public org.kie.local.HelloProcessInstance createInstance(java.lang.String businessKey, org.kie.local.HelloModel value) {
        return new org.kie.local.HelloProcessInstance(this, value, businessKey, this.createProcessRuntime());
    }

    public org.kie.local.HelloProcessInstance createInstance(java.lang.String businessKey, org.kie.kogito.correlation.CompositeCorrelation correlation, org.kie.local.HelloModel value) {
        return new org.kie.local.HelloProcessInstance(this, value, businessKey, this.createProcessRuntime(), correlation);
    }

    @Override()
    public org.kie.local.HelloModel createModel() {
        return new org.kie.local.HelloModel();
    }

    public org.kie.local.HelloProcessInstance createInstance(org.kie.kogito.Model value) {
        return this.createInstance((org.kie.local.HelloModel) value);
    }

    public org.kie.local.HelloProcessInstance createInstance(java.lang.String businessKey, org.kie.kogito.Model value) {
        return this.createInstance(businessKey, (org.kie.local.HelloModel) value);
    }

    public org.kie.local.HelloProcessInstance createInstance(org.kie.api.runtime.process.WorkflowProcessInstance wpi) {
        return new org.kie.local.HelloProcessInstance(this, this.createModel(), this.createProcessRuntime(), wpi);
    }

    public org.kie.local.HelloProcessInstance createReadOnlyInstance(org.kie.api.runtime.process.WorkflowProcessInstance wpi) {
        return new org.kie.local.HelloProcessInstance(this, this.createModel(), wpi);
    }

    protected org.kie.api.definition.process.Process process() {
        RuleFlowProcessFactory factory = RuleFlowProcessFactory.createProcess("hello", true);
        factory.name("Hello Process");
        factory.packageName("org.kie.local");
        factory.dynamic(false);
        factory.version("1.0");
        factory.type("BPMN");
        factory.visibility("Public");
        factory.metaData("jbpm.enable.multi.con", null);
        factory.metaData("jbpm.transactions.enable", "true");
        factory.metaData("TargetNamespace", "https://kie.apache.org/kie-local");
        org.jbpm.ruleflow.core.factory.StartNodeFactory<?> startNode_start = factory.startNode(org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_start"));
        startNode_start.name("Start");
        startNode_start.interrupting(true);
        startNode_start.metaData("UniqueId", "_start");
        startNode_start.metaData("EventType", "none");
        startNode_start.done();
        org.jbpm.ruleflow.core.factory.ActionNodeFactory<?> actionNode_log = factory.actionNode(org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_log"));
        actionNode_log.name("Log greeting");
        actionNode_log.metaData("UniqueId", "_log");
        actionNode_log.metaData("NodeType", "ScriptTask");
        actionNode_log.action(kcontext -> {
            System.out.println("Hello from the KIE local runtime");
        });
        actionNode_log.done();
        org.jbpm.ruleflow.core.factory.EndNodeFactory<?> endNode_end = factory.endNode(org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_end"));
        endNode_end.name("End");
        endNode_end.terminate(false);
        endNode_end.metaData("UniqueId", "_end");
        endNode_end.done();
        factory.connection(org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_start"), org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_log"), "_flow_start_to_log");
        factory.connection(org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_log"), org.jbpm.ruleflow.core.WorkflowElementIdentifierFactory.fromExternalFormat("_end"), "_flow_log_to_end");
        factory.validate();
        return factory.getProcess();
    }
}
