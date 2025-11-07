# Network Policy - CKAD Narration Script

Welcome to the CKAD exam preparation module for Kubernetes Network Policy. This session focuses specifically on what you need to know for the Certified Kubernetes Application Developer exam. Network Policy is classified as a supplementary topic, which means it's helpful to know and may appear on the exam, but it's not as heavily weighted as core topics like Pods, Deployments, or Services. However, when network policy questions do appear, candidates often struggle because there's no imperative command to help you. You must write YAML from scratch, and under time pressure, that can be challenging.

In this session, we'll cover the exam-specific patterns you need, the common scenarios that appear, effective debugging techniques, and most importantly, the pitfalls that trip up candidates. By the end, you'll be able to quickly write network policy YAML during the exam and troubleshoot connectivity issues efficiently.

## CKAD Exam Context

The CKAD exam expects you to demonstrate several specific competencies with network policies. You need to understand ingress and egress traffic control, knowing which direction each rule type affects. You must be able to use Pod selectors and namespace selectors correctly, understanding scope and selection. Port-based restrictions are important, allowing specific protocols and ports while blocking others. CIDR-based rules come up for controlling access to IP blocks. You'll need to implement default deny policies as the foundational security pattern. And critically, you must be able to debug network connectivity issues when things don't work as expected.

The exam is performance-based. You'll be given a scenario describing security requirements, and you'll need to create policies that implement those requirements. Speed matters significantly. If you're constantly referring to documentation or trying to remember syntax, you'll run out of time. The goal is to write YAML confidently from memory for common patterns.

The single most important concept for the exam is that network policy is additive. This affects every policy you write, so let me emphasize it clearly. When multiple network policies select the same Pod, they combine to create a union of allowed traffic. If any policy allows a specific traffic pattern, that traffic is permitted. You cannot write a policy to deny traffic that another policy allows. This behavior is identical to RBAC. It's a whitelist model where you start with no access and explicitly grant permissions.

Here's what this means in practice. If one policy allows traffic from Pods labeled app equals frontend, and another policy allows traffic from Pods labeled app equals backend, then both frontend and backend Pods can reach the target Pod. The policies don't conflict or override each other. They combine. The corollary is equally important. To block traffic, you simply don't allow it in any policy. There is no explicit deny rule in network policies.

Always test connectivity after applying policies. On the exam, verification is crucial. Don't just apply a policy and assume it works. Test that allowed traffic succeeds and blocked traffic fails. This verification is often part of the grading criteria.

One more critical exam point. Not all Kubernetes clusters enforce network policy. The exam environment should support it, but you need to understand why policies might not work. Local development clusters often lack the necessary CNI plugin. Docker Desktop doesn't enforce policies. You need Calico, Cilium, Weave, or another policy-aware CNI. This won't be an issue during the exam itself, but understanding this helps you troubleshoot problems.

## NetworkPolicy Basics

Network policies work at the Pod level, not the Service level. This is a common point of confusion. Policies select target Pods using label selectors. They define ingress rules for incoming traffic, egress rules for outgoing traffic, or both. The rules are allow-lists following a whitelist model. Multiple policies are additive, creating a union of all rules. Without any policy affecting a Pod, all traffic is allowed. Once even one policy selects a Pod, that Pod becomes subject to policy enforcement.

The basic structure consists of four main sections. The podSelector determines which Pods this policy applies to. An empty selector with just curly braces means all Pods in the namespace. The policyTypes field lists which traffic directions this policy controls, either Ingress, Egress, or both. The ingress section contains rules for incoming traffic, and the egress section contains rules for outgoing traffic. Each rule can specify sources or destinations using Pod selectors, namespace selectors, or IP blocks, along with optional port restrictions.

## Imperative vs Declarative

Here's a challenge unique to network policy. There is no kubectl create command that generates a complete, functional policy. You can run kubectl create networkpolicy with the dry-run flag to get output, but this only produces an empty skeleton. You still need to fill in the podSelector, policyTypes, ingress rules, and egress rules manually. For many candidates, it's actually faster to write the YAML from memory than to use this command and then edit the result.

My recommendation is to memorize templates for common patterns. Have a mental template for allowing traffic from specific Pods, allowing egress to APIs, and creating default deny policies. During the exam, you can type these quickly and modify them for the specific scenario. Practice writing policies from scratch until it becomes automatic. Get comfortable with your editor, whether that's vim or nano. Know how to create YAML files, edit them efficiently, and apply them without fumbling.

The commands you'll use frequently are straightforward. Getting policies uses kubectl get networkpolicy or the shorthand netpol. Describing policy details shows which Pods are selected and what rules apply. Applying your YAML uses kubectl apply with the filename. Deleting a policy if you need to fix it uses kubectl delete networkpolicy.

## Default Deny Policies

Default deny policies are fundamental patterns you must know cold for the exam. There are three essential patterns. Deny all ingress blocks all incoming traffic while allowing outgoing traffic. The YAML specifies Ingress in the policyTypes field but provides no ingress rules. An empty podSelector means it applies to all Pods in the namespace. Deny all egress blocks all outgoing traffic but allows incoming traffic. The YAML specifies Egress in policyTypes but provides no egress rules. Deny all traffic combines both, listing both Ingress and Egress in policyTypes with no rules for either. This creates complete isolation with no traffic in or out.

The key to understanding these patterns is recognizing what happens when you specify a policyType but provide no rules for that type. This creates a default deny for that direction. An empty rules section doesn't mean "allow everything." It means "allow nothing."

You might encounter an exam scenario asking you to create a default deny policy and verify that it blocks traffic. The workflow would involve creating the policy with an empty podSelector and both policyTypes, then creating test Pods to verify they cannot communicate. Testing with wget or curl should timeout, confirming the policy is enforced. This timeout is your verification that the policy works correctly.

A common mistake that trips up exam candidates is misunderstanding what an empty podSelector means. The curly braces, podSelector with just empty braces, means ALL Pods, not none. This is intentional and powerful. It's how you apply a policy to every Pod in a namespace, which is exactly what you want for default deny. If you wanted to select no Pods, you wouldn't use network policy at all, or you'd use a selector that matches nothing. Empty selector equals universal application within the namespace. This is consistent with other Kubernetes resources where empty selectors have the same meaning.

## Ingress Rules (Incoming Traffic)

The most common exam scenario involves allowing traffic from one set of Pods to another. For example, you might be asked to allow traffic from app equals web Pods to app equals api Pods on port eight thousand eighty. The pattern is straightforward once you understand the structure. The policy's podSelector at the top level targets the destination, the Pods receiving traffic. The podSelector inside the from section specifies the source, the Pods sending traffic. This distinction is crucial because mixing them up is a common error.

Cross-namespace communication presents a more advanced scenario. You might need to allow Pods in a frontend namespace to access API Pods in a backend namespace. This requires namespace selectors. Here's the important insight: namespace selectors match namespaces by their labels, not by their names directly. You need to verify or add a label to the source namespace first. Then your policy uses namespaceSelector in the from section, matching the namespace label.

This pattern allows traffic from any Pod in any namespace with the matching label. If you want to be more specific, restricting to certain Pods in certain namespaces, you combine both selectors in the same list item. When namespaceSelector and podSelector appear in the same list item under the same dash, it creates an AND condition. The Pod must have the matching label AND must be in a namespace with the matching label. Both conditions must be true for traffic to be allowed.

Understanding OR versus AND logic in ingress rules is critical for the exam. This trips up many candidates. When namespaceSelector and podSelector are in the same list item, indicated by being under the same dash, it's an AND condition. Both must match. When they're in separate list items with separate dashes, it's an OR condition. Either can match, and traffic is allowed.

Here's an example of OR logic. Multiple dashes under the from section create separate rules. Traffic is allowed from Pods with one label OR from any Pod in namespaces with another label. Either condition permits the traffic. Here's an example of AND logic. A single dash with both selectors means traffic is allowed from Pods with a specific label that are also in namespaces with a specific label. Both conditions are required.

On the exam, read the requirements carefully. The wording matters significantly. "From web OR from prod namespace" is different from "from web Pods in prod namespace." These are different requirements that need different policy structures.

Sometimes you need to allow or block traffic based on IP addresses. An exam question might ask you to allow traffic from IP range one ninety two dot one sixty eight dot one dot zero slash twenty four except one ninety two dot one sixty eight dot one dot five. This uses ipBlock in the from section. The cidr field specifies the allowed range, and the except field lists specific IPs or ranges to exclude from that CIDR.

Common use cases include allowing traffic from specific external networks, allowing traffic from node networks, or blocking cloud metadata services at the IP one sixty nine dot two fifty four dot one sixty nine dot two fifty four. Note that ipBlock works with actual IP addresses, not DNS names. If the exam gives you a hostname, you cannot use it directly in ipBlock. You'd need to resolve it to IP addresses first.

## Egress Rules (Outgoing Traffic)

This is the number one mistake on the exam, so pay close attention. Forgetting to allow DNS in egress policies causes more failures than anything else. Here's what happens. You create an egress policy that allows your web Pod to connect to your API Pod. You test it using the service name, and it fails with "bad address" or "unknown host." Why? Because the Pod cannot resolve the service name to an IP address. DNS is blocked by your egress policy.

Every egress policy must include a rule allowing DNS unless you're explicitly blocking all outgoing traffic. DNS uses UDP port fifty three to the kube-system namespace where CoreDNS runs. The standard pattern includes a to section with a namespaceSelector for kube-system and a ports section for UDP fifty three. Some clusters might also need TCP port fifty three, and you might need to select the CoreDNS Pods specifically depending on how the kube-system namespace is labeled.

On the exam, if DNS isn't working, check your egress policies first. This is almost always the culprit when service name resolution fails.

After DNS, you need to allow egress to your actual destination services. If the exam asks you to allow app equals web Pods to connect to app equals api Pods on port eight thousand eighty, this is an egress policy on the web Pods. But remember, you also need DNS. These appear as two separate list items, two separate dashes under egress. Each creates a separate rule. The Pod can access DNS OR the API. These are OR'd together, and both are allowed.

Sometimes Pods need to access external services outside the cluster. The exam might ask you to allow web Pods to access external HTTPS services. This uses ipBlock with zero dot zero dot zero dot zero slash zero to represent "any IP address." The ports section restricts it to HTTPS on port four forty three. You can make this more restrictive using the except field to block specific ranges even though the CIDR would normally include them.

A complete realistic example combines DNS and external access. The first egress rule allows DNS to the kube-system namespace on UDP and TCP port fifty three. The second rule allows HTTPS to anywhere except the cloud metadata service IP. This pattern is common in real-world scenarios and appears frequently in exam questions.

## Common CKAD Patterns

A classic exam scenario involves securing a three-tier application with web, API, and database layers. The requirements typically specify that the web tier accepts traffic from anywhere on port eighty, the web can connect to API on port eight thousand eighty, the API accepts traffic from web only, the API can connect to database on port five thousand four thirty two, the database accepts traffic from API only, and all tiers can access DNS.

This requires three policies, one for each tier. The database policy allows ingress from Pods labeled tier equals api on port five thousand four thirty two. It allows egress to DNS in kube-system. Notice there's no egress to other services because the database doesn't initiate connections to other tiers. The API policy has both ingress and egress. Ingress allows traffic from tier equals web on port eight thousand eighty. Egress allows connections to tier equals database on port five thousand four thirty two and to DNS. The web policy allows ingress from anywhere using an empty from selector. Egress allows connections to tier equals api on port eight thousand eighty and to DNS.

Another common pattern is namespace isolation, where Pods can only communicate with others in the same namespace. This is simpler than it might seem. The policy applies to all Pods in the namespace using an empty podSelector at the top level. It allows ingress from all Pods using an empty podSelector in the from section. Because namespaceSelector isn't specified, it defaults to the current namespace only. Result: Pods in the namespace can communicate with each other, but Pods from other namespaces cannot reach them.

If you want egress isolation too, add an egress section with the same pattern. Now Pods can only talk to each other and to DNS. This creates complete namespace isolation while still allowing the necessary internal communication.

Sometimes you need to explicitly allow all traffic, usually to override a more restrictive default deny policy. Allow all ingress uses an empty rule in the ingress section. That empty curly braces means "allow from anywhere" with no from section at all. Allow all egress uses an empty rule in the egress section with no to section, meaning "allow to anywhere." These patterns are useful when you have a default deny policy but need certain Pods to be unrestricted.

## Testing NetworkPolicy

On the exam, you must verify your policies work. Testing commands are essential. For HTTP connectivity, wget with the timeout flag prevents failed connections from hanging and wasting time. For arbitrary ports, netcat with the z flag checks if a port is open, and v is verbose. For DNS specifically, nslookup tests name resolution. If this fails, your egress policy probably blocks DNS. For getting Pod IPs when you need to test without DNS, use the wide output format or JSONPath queries.

When something doesn't work, here's your debugging workflow. First, list all policies in the namespace to see what exists. Describe the specific policy to see what it's doing. Pay attention to the Pod Selector line showing which Pods are affected and how many match. Check Pod labels to ensure they match your selectors. If labels don't match, your policy won't apply to those Pods. Check namespace labels for namespaceSelector issues. If you're trying to match a namespace but it doesn't have the required label, your policy won't work. Verify that your CNI actually enforces network policy by checking for Calico, Cilium, or Weave Pods in kube-system.

Common debugging scenarios come up repeatedly. If your app can't reach the API, check whether the app Pod has an egress policy, whether it allows the API Pod's selector and port, and whether it allows DNS. Quick test: can the Pod resolve the service name? If DNS resolution fails, DNS is blocked. If it succeeds but the connection fails, the egress rule might not match the API Pod correctly.

If your API isn't receiving traffic, check whether the API Pod has an ingress policy and whether it allows the source Pod's selector and the correct port. Verify the source Pod's labels match the podSelector in the API's ingress policy. For cross-namespace communication issues, check whether the namespace has the required label. If the label is missing, add it with kubectl label namespace, then test again.

## CKAD Exam Scenarios

Let me walk through the scenarios you're most likely to encounter. For allowing web to API communication, the task typically asks you to create a network policy so web can access API on a specific port. The solution applies to the API Pods and allows ingress from web Pods on the specified port.

For namespace-level isolation, you'll create a network policy in a specific namespace that only allows traffic from Pods within the same namespace. The solution uses an empty podSelector to select all Pods and allows ingress with an empty podSelector in the from section, which defaults to the current namespace.

For allowing only specific namespaces, you'll create a policy that allows ingress only from Pods in namespaces with a specific label. The solution uses namespaceSelector in the from section matching the namespace label.

For a database with multiple clients, you'll allow ingress on a database port from both API and analytics Pods. The solution lists multiple podSelectors in the from section as separate list items, creating an OR condition.

For egress with DNS, you'll create a policy allowing egress to API Pods and DNS queries. The solution has two separate egress rules: one for DNS to kube-system, and one for API access. Note that DNS selector syntax might vary by cluster, so you might need to adjust the label selector for DNS Pods.

## Advanced Topics

Named ports in network policy allow you to reference ports by name as defined in Pod specs instead of using numbers. This provides flexibility and maintainability. If you define a port name in a Pod's containerPort section, the network policy can reference that name instead of the numeric port. This is especially useful when port numbers might change between versions but the name remains constant.

Network policies combine additively when multiple policies select the same Pod. There's no precedence or priority. All matching policies apply simultaneously. The union of all rules determines what's allowed. Any policy allowing traffic permits it. You cannot use one policy to deny what another allows. Order doesn't matter because policies are evaluated together. This additive pattern is useful for incremental access. Start with a default deny policy, then add specific allow policies as needed.

For stateful sets, Pods need to communicate with each other for replication and clustering. Egress rules must allow Pod-to-Pod communication within the stateful set. Each Pod has a stable DNS name, but network policy applies to all replicas using the same labels. You'll typically allow ingress from application Pods and egress both to DNS and to other Pods in the same stateful set.

## Cleanup

Cleanup commands are straightforward. Delete a specific network policy by name, delete all network policies in a namespace with the all flag, delete by label selector, or delete in a specific namespace. On the exam, cleaning up after yourself isn't usually required unless explicitly stated, but knowing these commands helps you reset if you need to start over on a problem.

## Next Steps

After mastering network policy for CKAD, continue practicing with related topics. Namespaces are often combined with network policy for security boundaries. Services help you understand Pod-to-service communication patterns. RBAC provides access control that complements network control. Ingress covers external access patterns that work alongside internal network policies.

That completes our CKAD preparation for Kubernetes Network Policy. The key to success is practice. Write policies from scratch repeatedly until it becomes automatic. Set up test scenarios and secure them. Break things intentionally and fix them. Build the muscle memory you need for exam speed. Remember that network policy questions require writing YAML without imperative commands, so memorizing common patterns makes all the difference. Practice deliberately and repeatedly, and you'll be ready for whatever network policy scenarios appear on your exam.
