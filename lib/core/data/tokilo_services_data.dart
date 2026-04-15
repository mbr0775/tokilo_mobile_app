// lib/core/data/tokilo_services_data.dart
//
// PERMANENT hardcoded service catalogue for Tokilo Technologies.
// These 7 divisions + their sub-services NEVER change via admin.
// Admin `services` table is used for client project tracking only.

import 'package:flutter/material.dart';

// ── Data classes ─────────────────────────────────────────────────────────────

class TService {
  final String id;          // unique stable id used for portal pre-fill
  final String name;
  final String description;
  final String priceLabel;  // display price / "Get Quote"
  final String? duration;

  const TService({
    required this.id,
    required this.name,
    required this.description,
    required this.priceLabel,
    this.duration,
  });
}

class TDivision {
  final String id;
  final String name;
  final String tagline;
  final String emoji;
  final IconData icon;
  final String colorHex;      // primary colour for this division
  final String bgColorHex;    // light background tint
  final List<TService> services;

  const TDivision({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.icon,
    required this.colorHex,
    required this.bgColorHex,
    required this.services,
  });

  Color get color => Color(int.parse('0xFF$colorHex'));
  Color get bgColor => Color(int.parse('0xFF$bgColorHex'));
}

// ── Catalogue ─────────────────────────────────────────────────────────────────

const List<TDivision> kTokiloDivisions = [

  TDivision(
    id: 'software-dev',
    name: 'Software Development',
    tagline: 'Custom Software & Application Development',
    emoji: '💻',
    icon: Icons.code_rounded,
    colorHex: '6366F1',
    bgColorHex: 'EEF2FF',
    services: [
      TService(id: 'web-app-dev',      name: 'Web Application Development',  description: 'Scalable, modern web apps tailored to your business needs.',   priceLabel: 'Get Quote', duration: '4–12 weeks'),
      TService(id: 'mobile-app-dev',   name: 'Mobile App Development',       description: 'Native & cross-platform apps for Android and iOS.',             priceLabel: 'Get Quote', duration: '6–16 weeks'),
      TService(id: 'saas-dev',         name: 'SaaS Product Development',     description: 'End-to-end SaaS platforms with subscriptions & multi-tenancy.', priceLabel: 'Get Quote', duration: '8–20 weeks'),
      TService(id: 'enterprise-sw',    name: 'Enterprise Software Solutions', description: 'Robust enterprise systems for large-scale operations.',         priceLabel: 'Get Quote'),
      TService(id: 'api-integration',  name: 'API Integration',              description: 'Seamlessly connect your systems with third-party APIs.',        priceLabel: 'From QAR 3,000', duration: '1–3 weeks'),
      TService(id: 'biz-automation',   name: 'Business Automation Systems',  description: 'Automate workflows and reduce manual overhead.',                priceLabel: 'Get Quote', duration: '2–6 weeks'),
    ],
  ),

  TDivision(
    id: 'retail-tech',
    name: 'Retail Technology',
    tagline: 'Retail Digital Transformation Provider',
    emoji: '🏪',
    icon: Icons.storefront_rounded,
    colorHex: '0EA5E9',
    bgColorHex: 'E0F2FE',
    services: [
      TService(id: 'shop-crm',       name: 'Shop CRM Systems',            description: 'Manage customers, loyalty & sales from one dashboard.',    priceLabel: 'From QAR 5,000', duration: '2–4 weeks'),
      TService(id: 'pos-system',     name: 'POS (Point of Sale) Systems', description: 'Fast, reliable POS for retail and hospitality.',           priceLabel: 'From QAR 4,000', duration: '1–2 weeks'),
      TService(id: 'inventory-mgmt', name: 'Inventory Management',        description: 'Real-time stock tracking across all your locations.',       priceLabel: 'From QAR 3,500', duration: '1–3 weeks'),
      TService(id: 'multi-branch',   name: 'Multi-Branch Retail Systems', description: 'Centralise operations across multiple stores seamlessly.',  priceLabel: 'Get Quote'),
      TService(id: 'billing-report', name: 'Billing & Reporting Systems', description: 'Automated invoicing, analytics & financial reporting.',     priceLabel: 'From QAR 2,500', duration: '1–2 weeks'),
    ],
  ),

  TDivision(
    id: 'it-infra',
    name: 'IT Infrastructure & Networking',
    tagline: 'IT Infrastructure & Network Solutions Provider',
    emoji: '🌐',
    icon: Icons.router_rounded,
    colorHex: '06768D',
    bgColorHex: 'ECFEFF',
    services: [
      TService(id: 'lan-wan',        name: 'LAN / WAN Setup',             description: 'Design and deploy reliable wired networks for offices.',    priceLabel: 'Get Quote', duration: 'On-site'),
      TService(id: 'struct-cabling', name: 'Structured Cabling',          description: 'Professional cabling infrastructure built to last.',        priceLabel: 'Get Quote', duration: 'On-site'),
      TService(id: 'router-switch',  name: 'Router & Switch Config',      description: 'Optimised configuration for maximum throughput & uptime.',  priceLabel: 'From QAR 1,500', duration: '1–2 days'),
      TService(id: 'wifi-install',   name: 'Wi-Fi Installation',          description: 'Full-coverage enterprise Wi-Fi for any building size.',     priceLabel: 'From QAR 2,000', duration: '1–3 days'),
      TService(id: 'server-setup',   name: 'Server Setup',                description: 'On-premise server installation, config & hardening.',       priceLabel: 'Get Quote', duration: '2–5 days'),
      TService(id: 'vpn-remote',     name: 'VPN & Remote Access',         description: 'Secure remote access for your team from anywhere.',         priceLabel: 'From QAR 2,500', duration: '1–3 days'),
    ],
  ),

  TDivision(
    id: 'cyber-security',
    name: 'Cyber Security',
    tagline: 'Cyber Security & IT Protection Provider',
    emoji: '🛡️',
    icon: Icons.security_rounded,
    colorHex: 'EF4444',
    bgColorHex: 'FEF2F2',
    services: [
      TService(id: 'firewall-setup',   name: 'Firewall Setup',                  description: 'Enterprise-grade firewall deployment and management.',        priceLabel: 'From QAR 3,000', duration: '1–3 days'),
      TService(id: 'endpoint-prot',    name: 'Endpoint Protection',             description: 'Protect every device in your organisation.',                  priceLabel: 'From QAR 500/yr'),
      TService(id: 'vuln-assessment',  name: 'Vulnerability Assessment',        description: 'Identify and remediate security weaknesses before attackers.', priceLabel: 'Get Quote', duration: '1–2 weeks'),
      TService(id: 'pen-testing',      name: 'Penetration Testing',             description: 'Simulated cyber-attacks to test your real-world defences.',   priceLabel: 'Get Quote', duration: '1–2 weeks'),
      TService(id: 'backup-recovery',  name: 'Data Backup & Disaster Recovery', description: 'Automated backups and fast recovery when you need it most.',  priceLabel: 'From QAR 2,000'),
      TService(id: 'email-web-sec',    name: 'Email & Website Security',        description: 'Spam filtering, SSL, WAF and threat monitoring.',              priceLabel: 'From QAR 1,500/yr'),
    ],
  ),

  TDivision(
    id: 'physical-security',
    name: 'Physical Security Systems',
    tagline: 'Security & Surveillance Solutions',
    emoji: '🔐',
    icon: Icons.videocam_rounded,
    colorHex: '8B5CF6',
    bgColorHex: 'F5F3FF',
    services: [
      TService(id: 'cctv-install',   name: 'CCTV Installation',          description: 'Professional CCTV design and installation for any site.', priceLabel: 'Get Quote', duration: 'On-site'),
      TService(id: 'ip-camera',      name: 'IP Camera Systems',          description: 'High-definition IP cameras with remote monitoring.',      priceLabel: 'Get Quote', duration: 'On-site'),
      TService(id: 'biometric-ac',   name: 'Biometric Access Control',   description: 'Fingerprint & face recognition access management.',      priceLabel: 'From QAR 5,000', duration: '2–5 days'),
      TService(id: 'smart-lock',     name: 'Smart Lock Systems',         description: 'Keyless entry and access control for offices & homes.',   priceLabel: 'From QAR 1,500', duration: '1–2 days'),
      TService(id: 'alarm-systems',  name: 'Alarm Systems',              description: 'Intruder detection and alert systems for any premises.',  priceLabel: 'Get Quote', duration: 'On-site'),
    ],
  ),

  TDivision(
    id: 'cloud-devops',
    name: 'Cloud & DevOps',
    tagline: 'Cloud Engineering & Infrastructure Consulting',
    emoji: '☁️',
    icon: Icons.cloud_done_rounded,
    colorHex: '10B981',
    bgColorHex: 'ECFDF5',
    services: [
      TService(id: 'aws-azure-gcp',  name: 'AWS / Azure / GCP Deployment', description: 'Expert deployment and management on all major cloud providers.', priceLabel: 'Get Quote', duration: '1–4 weeks'),
      TService(id: 'cicd-pipeline',  name: 'CI/CD Pipeline Setup',         description: 'Automated build, test and deploy pipelines.',                   priceLabel: 'From QAR 4,000', duration: '1–2 weeks'),
      TService(id: 'docker-k8s',     name: 'Docker & Kubernetes',           description: 'Container orchestration for scalable, resilient services.',      priceLabel: 'Get Quote', duration: '1–3 weeks'),
      TService(id: 'infra-auto',     name: 'Infrastructure Automation',     description: 'IaC with Terraform, Ansible and more.',                         priceLabel: 'Get Quote'),
      TService(id: 'cloud-migration',name: 'Cloud Migration',               description: 'Smooth, zero-downtime migration from on-premise to cloud.',      priceLabel: 'Get Quote', duration: '4–12 weeks'),
    ],
  ),

  TDivision(
    id: 'ai-automation',
    name: 'AI & Automation',
    tagline: 'Intelligent Systems & Automation Provider',
    emoji: '🤖',
    icon: Icons.psychology_rounded,
    colorHex: 'F59E0B',
    bgColorHex: 'FFFBEB',
    services: [
      TService(id: 'ai-chatbots',    name: 'AI Chatbots',               description: 'Intelligent conversational AI for customer service & sales.',    priceLabel: 'Get Quote', duration: '3–8 weeks'),
      TService(id: 'biz-analytics',  name: 'Business Analytics Systems', description: 'Dashboards and insights that drive smarter decisions.',          priceLabel: 'Get Quote', duration: '2–6 weeks'),
      TService(id: 'sales-predict',  name: 'Sales Prediction Tools',    description: 'ML-powered forecasting to optimise your sales pipeline.',        priceLabel: 'Get Quote', duration: '3–8 weeks'),
      TService(id: 'proc-automation',name: 'Process Automation',        description: 'Automate repetitive tasks and free your team for what matters.', priceLabel: 'From QAR 5,000', duration: '2–6 weeks'),
    ],
  ),
];